package TargetAdapter;

# Adapt single reference sentence to a target object

use strict;
use warnings;

use Environment;
use ServiceClient;
use Similarity;
use String::Alignment;
use TargetAligner;
use Web::Summarizer::ExtractiveToken;

use Carp::Assert;
use Clone;
use FindBin;
use File::Slurp;
use File::Temp qw/ tempfile /;
use Function::Parameters qw(:strict);
use Graph::Writer::HTK;
use JSON;
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;
use Memoize;
use Net::Dict;
use Text::Levenshtein::Flexible qw( levenshtein levenshtein_l_all );

use Moose;
use namespace::autoclean;

# TODO : move all outputs to logger
binmode( STDERR , ':utf8' );

with( ServiceClient => { server_address => "http://barracuda.cs.columbia.edu:8989/" } );
with( 'DMOZ' );
with( 'Logger' );

our $REFERENCES_ANALYSIS_TERMS_ABSTRACTIVE = 'abstractive-terms';
our $REFERENCES_ANALYSIS_TERMS_FUNCTION = 'function-terms';
our $REFERENCES_ANALYSIS_TERMS_EXTRACTIVE = 'extractive-terms';
our $REFERENCES_ANALYSIS_TERMS_SUPPORTED = 'supported-terms';
our $REFERENCES_ANALYSIS_BOUNDARY_FUNCTION_ABSTRACTIVE = 'boundary_function_abstractive';
our $REFERENCES_ANALYSIS_BOUNDARY_ABSTRACTIVE_EXTRACTIVE = 'boundary_abstractive_extractive';
our $REFERENCES_ANALYSIS_SURFACE_TO_TOKEN = 'surface_2_token';
our $REFERENCES_ANALYSIS_REFERENCE_FREQUENCY = 'reference_frequency';

=pod
# appearance model
# TODO : make location of appearance model types / models list configurable
has 'appearance_model' => ( is => 'ro' , isa => 'AppearanceModel' , init_arg => undef , lazy => 1 , builder => '_appearance_model_builder' );
sub _appearance_model_builder {
    my $this = shift;
    return new AppearanceModel::Individual( individual_models_list => join( "/" , Environment->data_models_base , 'abstractive/summary_abstractive.predictive.models.list' ) );
}
=cut

has '_corpus_cost' => ( is => 'ro' , isa => 'CodeRef' , init_arg => undef , lazy => 1 , builder => '_corpus_cost_builder' );
sub _corpus_cost_builder {
    my $this = shift;

    my $cost_sub = sub {
	my $term = shift;
	return $this->global_data->global_count( 'summary' , 1 , lc( $term ) );
    };

    return $cost_sub;

}

# target aligner
# TODO : mode to sub-class for all TargetAdapter that perform adaptation by first aligning the reference and the target ?
has 'target_aligner_class' => ( is => 'ro' , isa => 'Str' , required => 0 );
has 'target_aligner_params' => ( is => 'ro' , isa => 'HashRef' , required => 0 );
has 'target_aligner' => ( is => 'ro' , isa => 'TargetAligner' , init_arg => undef , lazy => 1 , builder => '_target_aligner_builder' );
sub _target_aligner_builder {
    my $this = shift;
    my %aligner_params = %{ $this->target_aligner_params };
    # TODO : is there a way of sharing the target info ?
    $aligner_params{ 'target' } = $this->target;
    my $target_aligner = ( Web::Summarizer::Utils::load_class( $this->target_aligner_class ) )->new( %aligner_params );
    return $target_aligner; 
}

# target object
has 'target' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# output/log dir
# TODO : provide this field through a 'Loggable' role ?
has 'output_directory' => ( is => 'ro' , isa => 'Str' , required => 0 , predicate => 'has_output_directory' );

# extractive candidates (given the reference set ?)
has 'extractive_candidates' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_extractive_candidates_builder' );
sub _extractive_candidates_builder {
    my $this = shift;
    my @extractive_candidates = grep { ! $this->is_token_abstractive( $_ ); } uniq grep { length( $_ ) > 1; } split /\s+/ , $this->target->get_field( 'content.rendered' );
    return \@extractive_candidates;
}

# default candidates (to be used for unknown tokens)
has 'default_candidates' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_default_candidates_builder' );
sub _default_candidates_builder {
    my $this = shift;
    my $sentence_token_corpus_frequency = $this->global_data->global_distribution( 'summary' , 1 );
    my $candidate_count = scalar( keys( %{ $sentence_token_corpus_frequency } ) );
    my $candidate_probability = 1 / $candidate_count;
    my @selected_candidates = grep { $_ !~ m/\p{Punct}/ && $_ !~ m/^<.+>$/ } uniq keys( %{ $sentence_token_corpus_frequency } );
    my %default_candidates;
    map { $default_candidates{ $_ } = $candidate_probability; } @selected_candidates;

    return \%default_candidates;
}

# abstractive terms/models list file
# TODO: make configurable
has 'abstractive_models_list_file' => ( is => 'ro' , isa => 'Str' , default => join( "/" , Environment->data_models_base , 'abstractive/summary_abstractive.predictive.models.list' ) );

=pod
# abstractive terms/models
has 'abstractive_models' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_abstractive_models_builder' );
sub _abstractive_models_builder {
    my $this = shift;
    my %abstractive_models;
    map { $abstractive_models{ $_->[ 0 ] } = $_->[ 1 ]; }
    grep { $this->abstractive_ok( $_->[ 0 ] ); }
    map { chomp; my ( $term , $model_file ) = split /\t/ , $_; [ $term , $model_file ]; }
    read_file( $this->abstractive_models_list_file );
    return \%abstractive_models;
}
=cut

# neighborhood
# TODO : move to a NeighborhoodBasedTargetAdapter sub-class ?
has 'neighborhood' => ( is => 'ro' , isa => 'Web::Summarizer::ReferenceTargetSummarizer::Neighborhood' , required => 1 );

# reference sentence
has 'reference_sentence' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 1 );

has 'adapted_uncompressed' => ( is => 'ro' , isa => 'Web::Summarizer::GeneratedSentence' , init_arg => undef , lazy => 1 , builder => '_adapted_uncompressed_builder' );
sub _adapted_uncompressed_builder {
   
    my $this = shift;
   
    # generate confusion network based on reference-target alignment and decode using LM trained (exclusively on target)
    my $adapted_sentence = $this->adapt( 0 );

    # TODO : this is not going to work unless we can guarantee that adapted_sentence will not get retokenized => how ?
    # => possible if the dependency/POS parsing all depend on the sequence of tokens and not on the raw string (i.e. only the sequence of tokens is dependent on the raw string)
    #affirm { $adapted_sentence->length == $this->reference_sentence->length } 'Length of original and uncompressed sentences must match' if DEBUG;

    return $adapted_sentence;

}

##has 'adapted_compressed' => ( is => 'ro' , isa => 'Web::Summarizer::GeneratedSentence' , init_arg => undef , lazy => 1 , builder => '_adapted_compressed_builder' );
##sub _adapted_compressed_builder {
sub adapted_compressed {
    my $this = shift;
    my $neighborhood_adapted = shift;
    my $adapted_sentence = $this->adapt( 1 );
    return $adapted_sentence;
}

has 'joint_abstractive_confidences' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_joint_abstractive_confidences_builder' );
sub _joint_abstractive_confidences_builder {

    my $this = shift;
    
    # generate features
    # TODO : this was (and this should be) coming from a configuration file
    my $features = { "content.rendered" => { "ngrams" => [1,2,3] , # TODO : "node-context" => 1
		     } ,
		     "url_words" => { "ngrams" => [1] } ,
		     "anchortext_basic" => { "ngrams" => [1] }
    };
    
    
    my $target_featurized = $this->target->featurize( $features );
    # TODO : is this the optimal way of mapping features ?
    ###my $target_featurized_mapped = $this->request( 'map_appearance_features' , $target_featurized );
    
=pod
    my $target_arff_fh = File::Temp->new( SUFFIX => '.arff');
    my $target_arff_filename = $target_arff_fh->filename;
    
    my $mapped_features = encode_json( $target_featurized_mapped );
    # TODO : can I come up with something cleaner (without replicating too much code with what's in Environment already) ?
    # E.g. can I automatically detect the base for the current sub-system ?
    my $arff_generator = join( "/" , Environment->summarizer_base( 'graph-summarizer-4' ) , 'bin' , 'generate-appearance-arff' );
    my $arff_generation_command = "echo '$abstractive_model_file\t$target_arff_filename\t$mapped_features' | $arff_generator";
    `$arff_generation_command`;
    
    # 3 - evaluate
    my $bin_root = Environment->data_bin;
    my $weka_command = "$bin_root/binary-classifier-weka 'weka.classifiers.bayes.NaiveBayes' diag $target_arff_filename $abstractive_model_file 2>/dev/null";
    my @result = map { chomp; $_; } `$weka_command`;
    print join( "\n" , @result );
=cut

    # apply appearance model
    # TODO : should the feature mapping operation be abstracted by the appearance model ? probably ...
    #my $abstractive_confidences = $this->appearance_model->run( $target_featurized_mapped );
    my $target_url = $this->target->url;
    print STDERR ">> sending request to appearance model for $target_url ...\n";
    my $abstractive_confidences = $this->request( 'appearance' , 'default' , $target_featurized );

    return $abstractive_confidences;

}

sub abstractive_ok {

    my $this = shift;
    my $string = shift;

    if ( $string =~ m/^\d+$/ ) {
	return 0;
    }

    return 1;

}

# Is a token abstrative, i.e. do we have an abstractive model for it ?
sub is_token_abstractive {
    my $this = shift;
    my $token = shift;
    return defined( $this->joint_abstractive_confidences->{ lc( ref( $token ) ? $token->surface : $token ) } );
}

sub abstractive_confidence {

    my $this = shift;
    my $current_token = shift;
    my $token = shift;

    # TODO : is this the best place to filter candidates ?
    if (
# Note : we actually care about the predicted confidence for the current token
###	( lc( $current_token->surface ) eq lc( $token->surface ) ) ||
	( $current_token->pos ne $token->pos ) )
    {
	return 0;
    }


    my $token_surface_normalized = lc( $token->surface );
    my $abstractive_confidence = $this->joint_abstractive_confidences->{ $token_surface_normalized } || 0;

    # TODO : multiply by/interpolate with confidence from the reference set ?

    return $abstractive_confidence;

}

sub target_frequency {

    my $this = shift;
    my $token = shift;
    
    # Note : we define frequency as the number of modalities where token appears, is this reasonable ?
    my $frequency = scalar( keys( %{ $this->target_terms->{ $token } } ) ) || 0;

    return $frequency;

}

# TODO : for now we place this method in the graph transformation class, but this should be a transformation of its own (applied to elementary graphs)
sub adapt {

    my $this = shift;
    my $compressed = shift;
    my $neighbors = shift;

=pod
	# processing depends on the predicted token type
	# TODO : for now we skip unsupported adjectives here, but this should probably be handled on a per-token-type basis
	if ( $sentence_token_pos eq 'JJ' ) {
	    next;
	}
=cut

    my $adapted_sentence = $this->_adapt( $compressed , $neighbors );

    my $original_sentence = $this->reference_sentence;
    my $reference_url = $original_sentence->object->url;
    my $reference_title = $original_sentence->object->title_modality->content;
    my $target_title = $this->target->title_modality->content;
    my $adapted_sentence_score = $adapted_sentence->score;
    
    print STDERR "**************************************************************************************************\n";
    print STDERR "Reference  : $reference_url / $reference_title\n";
    print STDERR "Original   : $original_sentence\n";
    print STDERR "Adapted  sentence: $adapted_sentence [score: $adapted_sentence_score / compressed: $compressed]\n";
    print STDERR "\n";
    #print STDERR "Ground     : $target_ground_truth \n";
    #print STDERR "Title      : $target_title \n";
    print STDERR "**************************************************************************************************\n\n";

    return $adapted_sentence;
    
}

sub token_2_simplified {

    my $this = shift;
    my $sentence_token = shift;

    # we just drop adjectives
    if ( $sentence_token->pos eq 'JJ' ) {
	return undef;
    }

    return $sentence_token;

}

sub token_2_extractive_slot {

    my $this = shift;
    my $target = shift;
    my $sentence_token = shift;
    my $black_list = shift;
    my $core_entity = shift;
    my $keyphrases = shift;
    
    my $corrected_token = $sentence_token;

    return $corrected_token;

}

# TODO : this could be a trained model
sub token_2_abstractive_slot {

    # Note : simply return current token if it is considered acceptable ?

    my $this = shift;
    my $target = shift;
    my $sentence_token = shift;
    my $abstractive_terms = shift;
    my $tokens = shift;
    my $boundary_1 = shift;
    my $boundary_2 = shift;

    # 1 - list potential alternatives
    # TODO : softer POS match ?
    my @alternatives = grep { $sentence_token->pos eq $tokens->{ $_ }->pos && $sentence_token->surface ne $_ } keys( %{ $abstractive_terms } );
    
    # The closer we are to the lower boundary, the more likely this term is to be replaced
    my $sentence_token_surface = $sentence_token->surface;
    my $sentence_token_rank = $abstractive_terms->{ $sentence_token_surface } || $boundary_2 ;
    my $probability_abstractive_replacement = 1 - ( ( $sentence_token_rank - $boundary_2 ) / ( $boundary_1 - $boundary_2 ) );

    my $corrected_token;

    if ( scalar( @alternatives ) ) {

	# create a slot token ?
	
	# CURRENT : how do I prioritize ? probabilities ?
	foreach my $alternative (@alternatives) {
	    #$probability_to_be_semantically_relevant = $use_semantic_representations_and_normalize;
	}

	# CURRENT : Viterbi doable ?

    }
    else {

	# there is nothing we can do
	$corrected_token = $sentence_token;

    }

    # CURRENT : semantic distance between term and object ==> must have direct evidence ?
    # TODO : direct evidence / appearance mode for all candidate terms ?
###    if ( $this->_has_entry( $abstractive_terms , $sentence_token->surface , 1 ) ) {
###	return 1;
###    }
   

 
    # CURRENT : how do we set the threshold ?
    
    # By default assume non-compatible
    return $corrected_token;

}

sub _has_entry {

    my $this = shift;
    my $hash_ref = shift;
    my $key = shift;
    my $can_normalize = shift;

    return $hash_ref->{ $key } || ( $can_normalize ? $hash_ref->{ lc( $key ) } : 0 );

}

# Note : only called for tokens that are not supported by the target object
sub token_2_slot {

    my $token = shift;
    my $token_type = shift;
    my $abstractive_terms = shift;

}

# TODO : split into multiple atomic transformations ?
# i.e. 1 : mark potential slot locations / 2 : group adjacent slot locations / 3 : group parallel slot locations
sub transform {

    my $this = shift;
    my $word_graph = shift;
    my $target = shift;
    my $entries_ref = shift;

=pod
    # TODO
    #my $word_graph_clone = $word_graph->clone;
    my $word_graph_clone = $word_graph;

    # 1 - retrieve references from word-graph
    #my @references = map { $_->object } values( %{ $word_graph->paths } );
    my @references = @{ $entries_ref };

    # 6 - iterate over graph nodes to identify raw (single node) slot locations
    my %raw_slot_locations;
    my @nodes = $word_graph->vertices;
    foreach my $node ( @nodes ) {

	# 7 - determine whether node is a potential slot location
	my ( $slot_location_probability , $probability_prior , $probability_abstractive_slot , $probability_extractive_slot ) = $this->_slot_location_probability( $word_graph , $node , $target , $entries_ref );

	# 3 - processed with this node if slot location probability is not 0
	if ( $slot_location_probability ) {

	    my $raw_location_type = ( $probability_abstractive_slot > $probability_extractive_slot ) ? 'abstractive' : 'extractive';

	    # 5 - register slot location
	    # TODO : apply some sort of Slot role to node ?
	    # Note : these are individual nodes while the contexts may span multiple nodes
	    $raw_slot_locations{ $node } = [ $node , $slot_location_probability , $raw_location_type ];

	}

    }

    # 6 - loop over raw slot locations and expand to get all slot contexts
    my %contexts;
    my @_raw_slot_locations = keys( %raw_slot_locations );
    foreach my $_raw_slot_location_key (@_raw_slot_locations) {

	my $raw_slot_location_entry = $raw_slot_locations{ $_raw_slot_location_key };
	my $raw_slot_location_node = $raw_slot_location_entry->[ 0 ];
	my $raw_slot_location_type = $raw_slot_location_entry->[ 2 ];

	# expand on the predecessors side
	my $expansion_predecessors = $this->_expand( $word_graph , \%raw_slot_locations , $raw_slot_location_node , 0 );

	# expand on the successors side
	my $expansion_successors = $this->_expand( $word_graph , \%raw_slot_locations , $raw_slot_location_node , 1 );

	# generate all possible contexts resulting from the predecessors/successors expansions
	foreach my $expansion_predecessor_entry (@{ $expansion_predecessors }) {
	    foreach my $expansion_successor_entry (@{ $expansion_successors }) {
		
		my $expansion_predecessor = $expansion_predecessor_entry->[ 0 ];
		my $expansion_successor = $expansion_successor_entry->[ 0 ];

		if ( $expansion_predecessor eq $expansion_successor ) {
		    next;
		}

		my @slot_sub_path = ( @{ $expansion_predecessor_entry->[ 1 ] } , $raw_slot_location_node , @{ $expansion_successor_entry->[ 1 ] } );
		my $slot_sub_path_key = join( ':::' , @slot_sub_path );

		if ( defined( $contexts{ $slot_sub_path_key } ) ) {
		    # TODO : use $this->warn instead
		    print STDERR "Slot sub path ($slot_sub_path_key) discovered more than once ...\n";
		    next;
		}

		# determine context type
		my $context_type = ( scalar( grep { $_ eq 'extractive' } map { $raw_slot_locations{ $_ }->[ 2 ] } @slot_sub_path ) ) ? 'extractive' : 'abstractive';
		
		$contexts{ $slot_sub_path_key } = [ $expansion_predecessor , $expansion_successor , \@slot_sub_path , $context_type ];
		
	    }
	}
	
    }

    if ( scalar( keys( %contexts ) ) ) {
	
	my $filler_nodes_index_base = scalar(@nodes);
	my $n_fillers = 0;

	# 7 - process each context independently
	foreach my $context_key (keys( %contexts )) {

	    my $context_entry = $contexts{ $context_key };
	    my $context_start = $context_entry->[ 0 ];
	    my $context_end   = $context_entry->[ 1 ];
	    my $context_type  = $context_entry->[ 2 ];
	    
	    # 4 - determine slot type (if possible)
	    my $slot_type = $this->_slot_type( $word_graph , $context_entry );
	    if ( ! $slot_type ) {
		print STDERR "Unable to determine slot type ($context_start [...] $context_end), will not proceed ...\n";
		next;
	    }

	    # 8 - collect matching keyphrases in target document
	    # TODO : add some form of caching based on (target,type) ?
	    # TODO : do we really want to pass the word-graph object ?
	    my $slot_location_fillers = $context_type eq 'extractive' ?
		$this->_slot_location_fillers_extractive( $word_graph , $context_entry , $target , $slot_type , $keyphrases ) :
		$this->_slot_location_fillers_abstractive( $word_graph , $context_entry , $target , $slot_type , \@references )
		;

	    # 9 - create alternate paths (by-passes)
	    foreach my $slot_location_filler (@{ $slot_location_fillers }) {
		
		if ( defined( $slot_location_filler ) ) {
		    
		    # TODO : should we instantiate the token somewhere else ?
		    my $slot_location_filler_token = new Web::Summarizer::Token( surface => $slot_location_filler );

		    # 10 - create new node for this candidate filler
		    # TODO : is there a better way to generate a uid/index for this vertex ?
		    my $filler_node = $word_graph_clone->add_vertex( $slot_location_filler_token , $filler_nodes_index_base + $n_fillers++ );

		    # TODO : move this to WordGraph ?
		    $word_graph_clone->set_vertex_weight( $filler_node , 1 );
		    
		    # 11 - connect filler node to the start node for this context
		    $word_graph_clone->add_edge( $context_start , $filler_node );
		    
		    # 12 - connect filler node to the end node for this context
		    $word_graph_clone->add_edge( $filler_node , $context_end );
		    
		}
		else {

		    # 13 - create direct edge between start and end nodes
		    $word_graph_clone->add_edge( $context_start , $context_end );

		}
		
	    }
	    
	}

    }

    return $word_graph_clone;

=cut

}

# TODO : no longer needed ?
=pod
sub analyze_references {

    my $this = shift;

    my $target = $this->target;
    my $references = $this->references;

    my %surface_2_token;
    my %term_2_reference_frequency;
    my %term_2_corpus_frequency;
    my %term_2_supported;
    my %candidates2count;

    # 1 - list all abstractive terms in the provided references set
#    foreach my $reference (@{ $references }) {
    for (my $i=0 ; $i<scalar( @{ $references }); $i++) {
	my $reference = $references->[ $i ];

	# abstractive terms are terms that do not appear in the target content
	# TODO : use all references and previous computation

	my %_seen;
#	foreach my $reference_sequence_token (@{ $reference->[ 1 ] }) {

	for (my $j=0; $j<scalar(@{ $reference->[ 1 ]}); $j++) {
	    
	    my $reference_sequence_token = $reference->[ 1 ]->[ $j ];

	    # Note : not needed for this type of analysis
	    if ( $reference_sequence_token->is_special ) {
		next;
	    }

	    my $reference_sequence_token_surface = $reference_sequence_token->surface;	    
	    if ( defined( $_seen{ $reference_sequence_token_surface } ) ) {
		next;
	    }
	    $_seen{ $reference_sequence_token_surface } = 1;

	    $term_2_reference_frequency{ $reference_sequence_token_surface }++;

	    if ( ! defined( $term_2_corpus_frequency{ $reference_sequence_token_surface } ) ) {
		$term_2_corpus_frequency{ $reference_sequence_token_surface } = $this->global_data->global_count( 'summary' , 1 , $reference_sequence_token_surface );
	    }

	    # keep track of the token objects
	    # TODO : remove call to clone once the undef token bug has been fixed
	    $surface_2_token{ $reference_sequence_token_surface } = Clone::clone( $reference_sequence_token );

	    # we only consider NN or ADJ as having abstractive capabilities
	    # TODO : add POS role ?
	    # Note : for now we only work on NN, JJ is a little more involved
	    #if ( $reference_sequence_token->pos !~ m/^(NN|JJ)/ ) {
	    if ( $reference_sequence_token->pos !~ m/^(NN)/ ) {
		next;
	    }
	    
	    # TODO : create is_special method ?
	    if ( $reference_sequence_token->is_special ) {
		next;
	    }

	    my $reference_sequence_token_object_support = $reference_sequence_token->object_support( $reference->[ 0 ] , 1 );
	    if (
		# 1 - abstract terms are expected to not appear in the associated object
		! $reference_sequence_token_object_support
                # 2 - we're looking for terms that are not present in the sequence we are seeking to transform (not done here)
		) {
		$candidates2count{ $reference_sequence_token_surface }++;
	    }
	    else {
		$term_2_supported{ $reference_sequence_token_surface } += $reference_sequence_token_object_support;
	    }
	    
	}

    }

    # TODO : note that what we are doing here could probably be achieved in a more principled way using a 3-level (hierarchical ?) topic model

    # TODO : improve ? Introduce minimum rank threshold (10000 ?) in addition to minimum count
    my @abstractive_terms = sort { $term_2_corpus_frequency{ $b } <=> $term_2_corpus_frequency{ $a } } grep { $term_2_corpus_frequency{ $_ } > 2 } keys( %candidates2count );

    my $boundary_function_abstractive = $term_2_corpus_frequency{ $abstractive_terms[ 0 ] } + 1;
    my $boundary_abstractive_extractive = $term_2_corpus_frequency{ $abstractive_terms[ $#abstractive_terms ] } - 1;

    my @function_terms = grep { $term_2_corpus_frequency{ $_ } >= $boundary_function_abstractive; } keys( %term_2_reference_frequency );
    my @extractive_terms = grep { $term_2_corpus_frequency{ $_ } <= $boundary_abstractive_extractive; } keys( %term_2_reference_frequency );

    # normalize conditional support
    map { $term_2_supported{ $_ } /= $term_2_reference_frequency{ $_ }; } keys( %term_2_supported );
    
    # normalize reference frequencies
    map { $term_2_reference_frequency{ $_ } /= scalar( @{ $references } ) } keys( %term_2_reference_frequency );

    my %analysis;

    map {
	my $key = $_->[ 0 ];
	my $array_ref = $_->[ 1 ];
	my %hash;
	foreach my $entry (@{ $array_ref }) {
	    $hash{ $entry } = $term_2_corpus_frequency{ $entry }
	}
	$analysis{ $key } = \%hash;
    } ( [ $REFERENCES_ANALYSIS_TERMS_ABSTRACTIVE , \@abstractive_terms ] ,
	[ $REFERENCES_ANALYSIS_TERMS_FUNCTION , \@function_terms ] ,
	[ $REFERENCES_ANALYSIS_TERMS_EXTRACTIVE , \@extractive_terms ] );

    $analysis{ $REFERENCES_ANALYSIS_TERMS_SUPPORTED } = \%term_2_supported;
    $analysis{ $REFERENCES_ANALYSIS_BOUNDARY_FUNCTION_ABSTRACTIVE } = $boundary_function_abstractive;
    $analysis{ $REFERENCES_ANALYSIS_BOUNDARY_ABSTRACTIVE_EXTRACTIVE } = $boundary_abstractive_extractive;
    $analysis{ $REFERENCES_ANALYSIS_SURFACE_TO_TOKEN } = \%surface_2_token;
    $analysis{ $REFERENCES_ANALYSIS_REFERENCE_FREQUENCY } = \%term_2_reference_frequency;

    return \%analysis;

}
=cut

sub _expand {

    my $this = shift;
    my $word_graph = shift;
    my $raw_slot_locations = shift;
    my $_raw_slot_location = shift;
    my $direction = shift;

    my $direction_expander = $direction ? 'successors' : 'predecessors';

    my @expansion;
    my %seen;

    # TODO : rename
    my @_candidates = map { [ $_ , [] ]; } $word_graph->${direction_expander}( $_raw_slot_location );
    while ( scalar( @_candidates ) ) {

	my $current_candidate_entry = shift @_candidates;
	my $current_candidate = $current_candidate_entry->[ 0 ];
	my $current_path = $current_candidate_entry->[ 1 ];
	
	if ( $seen{ $current_candidate } ) {
	    # we've already seen this node, ignore
	    next;
	}
	elsif ( ! defined( $raw_slot_locations->{ $current_candidate } ) ) {
	    # we have reached a regular node, register as context predecessor
	    push @expansion , $current_candidate_entry;
	}
	else {
	    # we have reached another raw slot location, collect all predecessors for this location
	    push @_candidates , map { [ $_ ,
					$direction ? [ @{ $current_path } , $current_candidate  ] : [ $current_candidate , @{ $current_path } ]
		]; } $word_graph->${direction_expander}( $current_candidate );
	}
	
	$seen{ $current_candidate }++;
	
    }
    
    return \@expansion;

}

# TODO : keep ?
sub _slot_location_probability_pos {

    my $this = shift;
    my $node = shift;

    my $node_pos = $node->pos;
    
    if ( $node_pos =~ m/^VB/ ) {
	return 0;
    }

    return 1;

}

# TODO : to be removed
=pod
    # 1 - generate all 1-grams for the target object
    # TODO : make necessary changes to allow for the generation of at least 5-grams
    # TODO : make max ngram order a parameter ?
    my $object_ngrams = $object->get_all_modalities_ngrams( 1 );
=cut

sub _frequency {

    my $this = shift;
    my $object = shift;
    my $object_terms = shift;
    my @terms = @_;

    my $frequency = 0;
    foreach my $modality (@{ $object->modalities_ngrams }) {
	
	my $found = 1;

	foreach my $term (@terms) {

	    if ( ! $object_terms->{ $term }->{ $modality->id } ) {
		$found = 0;
		last;
	    }
	}

	$frequency += $found;

    }

    return $frequency;

}

sub _keyphrase_score_mutual_information {

    my $this = shift;
    my $object = shift;
    my $object_terms = shift;
    my $references_terms = shift;
    my $term1 = shift;
    my $term2 = shift;

=pod
    # TODO : add frequency caching ?
    my $p1  = $object->frequency( $term1 );
    my $p2  = $object->frequency( $term2 );
    my $p12 = $object->frequency( $term1 , $term2 );
=cut
    
    my $p1  = $this->_frequency( $object , $object_terms , $term1 );
    my $p2  = $this->_frequency( $object , $object_terms , $term2 );
    my $p12 = $this->_frequency( $object , $object_terms , $term1 , $term2 );

    my $p2_references = 0;
    map { $p2_references += scalar( keys( %{ $_->{ $term2 } } ) ) } @{ $references_terms };

    #return ( $p12 / ( $p1 * $p2 ) );
    return $p12 / ( $p2_references + 1 );

}

sub _target_keyphrases {

    my $this = shift;
    my $target = shift;
    my $target_terms = shift;
    my $references_terms = shift;
    my $core_entity = shift;

    # TODO : use frequency in references as an indication of whether the term/ngram is likely to be a keyphrase for a site of this category ?

    my @sorted_keyphrases = sort { $this->_keyphrase_score_mutual_information( $target , $target_terms , $references_terms , $core_entity , $b ) <=>
				       $this->_keyphrase_score_mutual_information( $target , $target_terms , $references_terms , $core_entity , $a ) } keys( %{ $target_terms } );

    # TODO : filter out overlapping keyphrases
    my $filtered_keyphrases = $this->_keyphrases_filter( \@sorted_keyphrases , 10 );

    # TODO : return keyphrase scores as well ?
    return $filtered_keyphrases;

} 

sub _keyphrases_filter {

    my $this = shift;
    my $keyphrases_raw = shift;
    my $limit = shift;

    my @keyphrases_filtered;
    my %seen;
    foreach my $keyphrase_raw (@{ $keyphrases_raw }) {

	my @keyphrase_elements = split /\s+/ , $keyphrase_raw;
	my @keyphrase_elements_clean;

	for (my $i=0; $i<=$#keyphrase_elements; $i++) {
	    my $keyphrase_element = $keyphrase_elements[ $i ];
	    if ( $keyphrase_element eq '[[null]]' ) {
		next;
	    }
	    elsif ( $keyphrase_element eq '<eod>' ) {
		if ( $i != 0 && $i != $#keyphrase_elements ) {
		    print STDERR "<eod> should not occur here ...\n";
		}
		next;
	    }
	    push @keyphrase_elements_clean , $keyphrase_element;
	}

	if ( ! scalar( @keyphrase_elements_clean ) ) {
	    next;
	}

	my $keyphrase_clean = join( " " , @keyphrase_elements_clean );
	if ( $seen{ $keyphrase_clean } ) {
	    next;
	}

	push @keyphrases_filtered , $keyphrase_clean;
	$seen{ $keyphrase_clean }++;

	if ( $limit && scalar( @keyphrases_filtered ) >= $limit ) {
	    last;
	}

    }

    return \@keyphrases_filtered;

}

# Entity key: term that has the strong tfidf within the references
sub _target_core_entity {

    my $this = shift;
    my $target = shift;
    my $target_terms = shift;
    my $references_terms = shift;
    
    my @sorted_terms = sort { $this->_core_score( $target , $target_terms , $references_terms , $b ) <=> $this->_core_score( $target , $target_terms , $references_terms , $a ) }
    grep { scalar( keys( %{ $target_terms->{ $_ } } ) ) > 1 } keys( %{ $target_terms } );

    my $core_entity = scalar( @sorted_terms ) ? $sorted_terms[ 0 ] : $target->get_field( 'url.words' );

    return $core_entity;

}

# 2 - rank 5-grams by decreasing tf-idf
# tf : number of target modalities where the n-gram occurs
# idf : inverse appearance frequencies in references (do not consider individual reference modalities)
sub _core_score {

    my $this = shift;
    my $target = shift;
    my $target_ngrams = shift;
    my $references_ngrams = shift;
    my $ngram = shift;

    my $tf = scalar( keys( %{ $target_ngrams->{ $ngram } } ) );
    my $df = scalar( grep { $_->{ $ngram } } @{ $references_ngrams } );
    my $url_distance = levenshtein( $target->url , $ngram );

    my $core_score = ( $tf / ( 1 + $url_distance ) ) * ( 1 / ( 1 + $df ) );

    return $core_score;

}

# TODO : use MI as a metric, using the entity of the web-site as a reference
# CURRENT : mi with regex matching for all available modalities (treat anchortext entries separately, but give lower vote to each)
# Keywords are based on mutual information, especially when compared to references ==> compute MI wrt target entity for all 5/6-grams and rank ==> keywords
# Then, rank by decreasing semantic similarity at slot level
sub _slot_location_probability {

    my $this = shift;
    my $token = shift;
    my $target = shift;
    my $entries_ref = shift;

    # 1 - p( slot | node )
    # TODO : is it ok to go through the target object to get corpus statistics about the node ?
    # TODO : what if the node store an n-gram (with n > 1) ?
    my $corpus_tf = $this->global_data->global_count( 'summary' , 1 , $token->surface );

    # CURRENT : top half / top 1000 of the corpus ==> seems like a reasonable threshold
    my $corpus_slot_probability = 1 / ( $corpus_tf + 1 );

    # 1 - check whether this node is supported by the target object
    my $is_supported_by_target = $token->object_support( $target );

    my $references_support = 0;
    my @reference_sequences = map { $_->[ 1 ] } @{ $entries_ref };

    my $reference_count_appears_in_summary = 0;
    my $reference_count_appears_in_summary_not_in_object = 0;
    my $reference_count_appears_in_summary_and_in_object = 0;
    
    for ( my $i = 0 ; $i <= $#reference_sequences ; $i++ ) {

	my $reference_sequence = $reference_sequences[ $i ];
        my $reference_sequence_support = $reference_sequence->contains( $token );

        my $reference_object = $reference_sequence->object;
        my $reference_object_support = $token->object_support( $reference_object );

=pod
    # 2 - check whether this node is supported by the reference objects (ratio ?)
    # Note : references support ==> (1) if in reference, should also appear in associated object; (2) if not in reference, should not appear in associated object => 1/0 votes for now
    # TODO : note this is duplicated from WordGraph::EdgeFeature::NodePrior, can we fix/improve ?
	
	# TODO : evaluate slot nature of node for reference $i with respect to the remaining references ?
	# i.e. the node should appear in the reference summary, appear in the reference object and not appear in any of the reference summaries + object ?

###	my @references_fold = map { $_->object } @reference_paths;
###	my $current_reference = splice @references_fold , $i , 1;
###	my $fold_support = map { }

        my $reference_vote = $reference_path_support ? $reference_object_support : 1 - $reference_object_support;
=cut

	# we're voting for the abstract-ness of this node ...
        # we're looking for reference paths that contain this node but where this node is not supported by the reference object
	# TODO : what happens if this node does not appear in any reference ? (impossible)
        my $reference_vote = $reference_sequence_support ? 1 - $reference_object_support : 1;

	$references_support += $reference_vote;

	$reference_count_appears_in_summary += $reference_sequence_support;
	$reference_count_appears_in_summary_not_in_object += $reference_sequence_support * ( 1 - $reference_object_support );
	$reference_count_appears_in_summary_and_in_object += $reference_sequence_support * $reference_object_support;

    }

    my $reference_count = scalar( @reference_sequences );
    my $probability_prior = $reference_count ? $reference_count_appears_in_summary / $reference_count : 0;

    # 1 - probability abstractive slot
    # Must be filled with an abstract terms implied by the target ==> produce ranking of abstractive terms that do not appear in the graph/path
    # Note : frequency condition to avoid using random strings as abstractive terms - TODO : make higher ?
    # Note : for now no condition on the term rank to allow for even obscure abstractive terms, provided they are frequent enough among the references (?)
    my $probability_abstractive_slot = ( $reference_count_appears_in_summary && $corpus_tf > 2 ) ? ( $reference_count_appears_in_summary_not_in_object / $reference_count_appears_in_summary ) : 0;
    
    # 2 - probability extractive slot
    # TODO : is_supported_by_target not really needed here
    # Must be filled with a term extracted from the target ==> produce ranking keyphrases that do not appear in the graph/path
    my $probability_extractive_slot = (1 - $is_supported_by_target) * ( $reference_count_appears_in_summary ? ( $reference_count_appears_in_summary_and_in_object / $reference_count_appears_in_summary ) : 0 );

    # normalize references support
    $references_support /= $reference_count || 1;

    my $pos_slot_probability = $this->_slot_location_probability_pos( $token );

    # p( slot location ) = p( slot location | target ) * proportion of references for which this node is likely to be a slot (i.e. supported and does not appear in others ?)
    my $slot_location_probability = ( $probability_prior < $probability_abstractive_slot || $probability_prior < $probability_extractive_slot ) ? $pos_slot_probability * $corpus_slot_probability * ( 1 - $is_supported_by_target ) * $references_support : 0; 

    return ( $slot_location_probability , $probability_prior , $probability_abstractive_slot , $probability_extractive_slot );

}

sub _slot_type_compatible {

    my $this = shift;
    my $slot_type = shift;
    my $slot_filler = shift;

    my $slot_filler_type = $this->_type( $slot_filler );

    return ( $slot_type eq $slot_filler_type );

}

sub _slot_type {

    my $this = shift;
    my $word_graph = shift;
    my $context_entry = shift;

    my $slot_verbalization = join( " " , map { $_->surface } @{ $context_entry->[ 2 ] } );

    return $this->_type( $slot_verbalization );

}

sub _slot_location_fillers_abstractive {

    my $this = shift;
    my $word_graph = shift;
    my $context_entry = shift;
    my $target = shift;
    my $slot_type = shift;
    my $references = shift;

    # TODO : add special handling for context that do not contain an np

    my %candidates2count;

    # TODO : move this up
    my @word_graph_paths_all = values( %{ $word_graph->paths } );
    my @word_graph_paths_matching;

    foreach my $word_graph_path (@word_graph_paths_all) {
	my $keep = 1;
	foreach my $context_node (@{ $context_entry->[ 2 ] }) {
	    if ( ! $word_graph_path->contains( $context_node ) ) {
		$keep = 0;
		last;
	    }
	}
	if ( $keep ) {
	    push @word_graph_paths_matching , $word_graph_path;
	}
    }

    # 1 - list all abstractive terms in the provided references set
    foreach my $reference (@{ $references }) {
	
	# abstractive terms are terms that do not appear in the target content
	# TODO : use all references and previous computation
	foreach my $reference_sequence_token (@{ $reference->[ 1 ] }) {

	    # we only consider NN or ADJ as having abstractive capabilities
	    # TODO : add POS role ?
	    if ( $reference_sequence_token->pos !~ m/^(NN|JJ)/ ) {
		next;
	    }

	    my $reference_sequence_token_surface = $reference_sequence_token->surface;

	    # TODO : create is_special method ?
	    #if ( $reference_sequence_token->is_special ) {
	    if ( $reference_sequence_token_surface eq '<bog>' || $reference_sequence_token_surface eq '<eog>' ) {
		next;
	    }

	    if (
		# 1 - abstract terms are expected to not appear in the associated object
		! $reference_sequence_token->object_support( $reference->[ 0 ] ) &&
		# 2 - we're looking for terms that are not present in the path we are updating
		! scalar( grep { $_->contains( $reference_sequence_token ); } @word_graph_paths_matching )
		) {
		$candidates2count{ $reference_sequence_token_surface }++;
	    }
	    
	}

    }

    my %abstractive_terms_2_global_counts;
    map { $abstractive_terms_2_global_counts{ $_ } = $this->global_data->global_count( 'summary' , 1 , $_ ); } keys( %candidates2count );

    # TODO : improve ?
    my @abstractive_terms = sort { $abstractive_terms_2_global_counts{ $b } <=> $abstractive_terms_2_global_counts{ $a } } grep { $abstractive_terms_2_global_counts{ $_ } > 2 } keys( %candidates2count );
    return \@abstractive_terms;
    
}

sub _slot_location_fillers_extractive {

    my $this = shift;
    my $word_graph = shift;
    my $context_entry = shift;
    my $target = shift;
    my $slot_type = shift;
    my $target_keyphrases = shift;

    my @fillers;

    # 1 - resolve type based on type of individual raw slot locations
    my $has_np  = 0;
    my $has_adv = 0;
    my $has_adj = 0;

    map {
	if ( $_->pos =~ m/^N/ ) { $has_np++; }
	elsif ( $_->pos =~ m/^JJ/ ) { $has_adj++; }
	elsif ( $_->pos =~ m/^ADV/ ) { $has_adv++; }
    } @{ $context_entry->[ 2 ] };

    # Note : we simply bypass adjective/adverb contexts
    # TODO : should we try something more refined ?
    my $allow_shunt = !$has_np && ( $has_adj || $has_adv );

    if ( $has_np ) {

	# 2 - collect slot fillers for the predicted slot type
	# TODO : can we make the slot type selection soft (i.e. based on a probability) ?
	
	# TODO : make sure the selected fillers are also supported as such by the references ?
	
	# CURRENT : candidates such the probability ratio as slot location is > 1 ?
	# Offers => low probability to be a slot location
	# Arizona => (assume appears in target, and by definition, somewhat likely to be a slot filler)

	# TODO : duplicated from WordGraph::Node::Slot ==> how can we fix this ?

	my $target_url = $target->url;

	my %filler_candidates;
	
	# TODO : implement multiple Keyphrase Extraction strategies
	# 1 - make sure we have the full list of instance fillers available
	#my $instance_fillers = $word_graph->data_extractor->collect_instance_fillers( $target );
	my $instance_fillers = $target_keyphrases;

=pod
	# 2 - collect fillers for the target node
	foreach my $instance_filler (@{ $instance_fillers }) {
	
	    # a filler candidate cannot appear as a regular node in the graph (makes sense)
	    # TODO: allow full ngram lookup ?
	    if ( scalar( @{ $this->graph()->get_nodes_by_surface( $instance_filler ) } ) ) {
		# do nothing
		next;
	    }

	    my $filler_confidence = $this->filler_confidence( $instance_filler );
	
	}
    
	# store in cache
	$this->filler_candidates()->{ $instance_url } = \%filler_candidates;
=cut

	push @fillers, grep { $this->_slot_type_compatible( $slot_type , $_ ); } @{ $instance_fillers };
	
    }

    if ( $allow_shunt ) {
	unshift @fillers , undef;
    }

    return \@fillers;

}

# CURRENT : must have a type for every slot location, otherwise do not treat as a slot location
sub _type {

    my $this = shift;
    my $string = shift;

    my $wn_type = $this->_type_wn( $string );
   
    my @string_tokens = split /\s+/ , $string;
    my $backoff_type = lc( $string_tokens[ $#string_tokens ] );

    return $wn_type || $backoff_type;

}

# ****************************************************************************************************************************************************************
# Support for synonym-based target adaptation (i.e. [keep])

sub is_keep_synonym {

    my $this = shift;
    my $token = shift;

    # 1 - get synsets for this token
    my $token_synsets = $token->synsets;

    # 2 - get set of synsets for the target object
    # TODO : per modality synsets ?
    my $target_synsets = $this->target->distribution_synsets;

    # 3 - check for overlap
    foreach my $token_synset (@{ $token_synsets }) {
	if ( defined( $target_synsets->{ $token_synset } ) ) {
	    return 1;
	}
    }

    return 0;

}

# ****************************************************************************************************************************************************************

__PACKAGE__->meta->make_immutable;

# Old code - especially anything that's related to the abstractive adaptation portion which now belongs in the fusion process

=pod    
    # 1 - generate list of abstractive terms for the target domain (based on references)
    my $abstractive_terms = $this->references_analysis->{ $REFERENCES_ANALYSIS_TERMS_ABSTRACTIVE };
    my $function_terms = $this->references_analysis->{ $REFERENCES_ANALYSIS_TERMS_FUNCTION };
    my $extractive_terms = $this->references_analysis->{ $REFERENCES_ANALYSIS_TERMS_EXTRACTIVE };
    my $conditional_supported_terms = $this->references_analysis->{ $REFERENCES_ANALYSIS_TERMS_SUPPORTED };
    my $boundary_function_abstractive = $this->references_analysis->{ $REFERENCES_ANALYSIS_BOUNDARY_FUNCTION_ABSTRACTIVE };
    my $boundary_abstractive_extractive = $this->references_analysis->{ $REFERENCES_ANALYSIS_BOUNDARY_ABSTRACTIVE_EXTRACTIVE };
    my $reference_frequencies = $this->references_analysis->{ $REFERENCES_ANALYSIS_REFERENCE_FREQUENCY };
=cut

=pod

	elsif ( $token_abstract_type eq 'SLOT_ABS' ) {
	    # abstractive token
	    # TODO : same as above
### WHY ???
###	    @token_alternatives = grep { $_->[ 1 ] } map { [ $_->surface , $this->abstractive_confidence( $token , $_ ) ] } values( %{ $this->references_analysis->{ $REFERENCES_ANALYSIS_SURFACE_TO_TOKEN } } );
	    my @candidates = values( %{ $this->references_analysis->{ $REFERENCES_ANALYSIS_SURFACE_TO_TOKEN } } );
	    for (my $candidate_i=0; $candidate_i<=$#candidates; $candidate_i++) {
		my $candidate = $candidates[ $candidate_i ];
		# TODO : how can we avoid creating this variable (i.e. how to interpolate an object field) ?
		my $candidate_surface = $candidate->surface;
###		print STDERR "\t\t requesting abstractive confidence for $token_surface_normalized/$candidate_surface ...\n";
		my $candidate_confidence = $this->abstractive_confidence( $token , $candidate );
###		print STDERR "\t\t confidence : $candidate_confidence\n";
		if ( $candidate_confidence ) {
		    $token_alternatives{ $candidate->surface } = $candidate_confidence;
		}
	    }

	    #keys( %{ $this->references_analysis->{ $REFERENCES_ANALYSIS_TERMS_ABSTRACTIVE } } );
	}

=cut

=pod

    # CURRENT / TODO : should not have to filter here ...
    my @sentence_tokens = grep { defined( $_ ) } @{ $sentence };
    my @transformed_sentence_tokens;
    my @first_pass_statuses;
    my %token2frequency;
    my %token2supported;

    # TODO : clean this up
    my $has_abstractive_slot = 0;
    my $has_extractive_slot = 0;

    # 2 - iterate over sentence tokens
    # TODO : need two passes to handle multi-word spans
    foreach my $sentence_token (@sentence_tokens) {
	
	# TODO : can I come up with something nicer ?
	my $sentence_token_special = $sentence_token->is_special;
	my $sentence_token_surface = $sentence_token->surface;
	my $sentence_token_pos = $sentence_token->pos;

	# TODO : can we do better ?
	my $sentence_token_surface_normalized = lc( $sentence_token_surface );

	# 3 - determine target support
	# TODO : cache ?
	my $sentence_token_target_supported = ( $sentence_token->object_support( $this->target , raw => 1 ) == 1 ) || 0;
	$token2supported{ $sentence_token_surface_normalized } = $sentence_token_target_supported;

	my $transformed_sentence_token;
	my $token_status = undef;

	# TODO : soften this up ? (Bayesian approach ?)
	if ( ! ( $sentence_token_special || $sentence_token_target_supported ) ) {

	    # determine reference support
	    my $sentence_token_reference_supported = ( $sentence_token->object_support( $sentence->object , allow_partial_match => 1 ) == 1 ) || 0;

	    # token frequency in summaries
	    # TODO : use the unnormalized version instead, however this means removing the (post) normalization in DMOZ::GlobalData
	    my $sentence_token_corpus_frequency = $this->global_data->global_count( 'summary' , 1 , $sentence_token_surface_normalized );
	    $token2frequency{ $sentence_token_surface_normalized } = $sentence_token_corpus_frequency;

	    # determine/predict type of token
	    # a : abstractive
	    # e : extractive
	    # p : abstractive/extractive
	    # u : unknown
	    # Note : can we have function words ? ==> or special case of abstractive ?
	    if ( $sentence_token_reference_supported ) {

		# TODO : introduce lower bound for extractive zone (instead of a hard does-not-appear-in-summary)
		if ( $sentence_token_corpus_frequency ) {
		    # (2) does not appear in target, appears in reference        , in vocabulary     : abstractive or extractive ==> probability to be abstractive vs extractive ?
		    $token_status = 'p';
		}
		else {
		    # (4) does not appear in target, appears in reference        , not in vocabulary : extractive (i.e. cannot possibly be abstractive)
		    $token_status = 'e';
		}

	    }
	    else {

		# (3) does not appear in target, does not appear in reference, in vocabulary     : abstractive or extractive ==> probability to be abstractive vs extractive ?
		if ( $sentence_token_corpus_frequency ) {
		    $token_status = 'p';
		}
		else {
		    # (3) does not appear in target, does not appear in reference, not in vocabulary : unknown or extractive (assume missing data ?)
		    # ==> if not in vocabulary, this is necessarily an extractive term
		    $token_status = 'u';
		}

	    }

	}
	else {

	    $token_status = 's';

	}

	if ( $token_status eq 'a' ) {
	    $transformed_sentence_token = new Web::Summarizer::Token( surface => $sentence_token_surface , pos => $sentence_token_pos , abstract_type => 'SLOT_ABS' );
	    $has_abstractive_slot++;
	}
	elsif ( $token_status eq 'e' ) {
	    $transformed_sentence_token = new Web::Summarizer::Token( surface => $sentence_token_surface , pos => $sentence_token_pos , abstract_type => 'SLOT_EXT' );
	    $has_extractive_slot++;
	}
	else {
	    $transformed_sentence_token = $sentence_token;
	}

	push @transformed_sentence_tokens , $transformed_sentence_token;
	push @first_pass_statuses , $token_status;

    }

=cut

=pod
            if ( $this->is_token_abstractive( $sentence_token ) ) {

	    }
            elsif ( $sentence_token_corpus_frequency >= $boundary_function_abstractive && ! defined( $abstractive_terms->{ $sentence_token_surface } ) && ! defined( $extractive_terms->{ $sentence_token_surface } ) ) {
		$token_status = 'f';

	    }
            elsif ( $sentence_token_pos =~ m/^(NN|JJ)/ && $sentence_token->object_support( $sentence->object , 1 ) > 0.5 ) {

	    }
	    else { # TODO : is this really the best default behavior ?
		$token_status = 'o';
		# TODO / Node : for now assume everything else is ok but should at least be simplified to avoid taking any chance
		$transformed_sentence_token = $this->token_2_simplified( $sentence_token );
	    }
=cut

=pod

    # generate sentence signature
    my $sentence_signature = join( "" , @first_pass_statuses );
    
    # adjust signature for extractive locations
    my $sentence_signature_corrected = $sentence_signature;
    while ( $sentence_signature_corrected =~ s/(ee+)/ my $match_length = length( $1 ); qq[e$match_length] /esig ) {}

    # second pass
    # TODO : need two passes to handle multi-word spans
    my @postprocessed_sentence_tokens;
    my $position = 0;
    while ( $sentence_signature_corrected =~ m/(\w)(\d+)?/sgi ) {
	
	my $token_signature = $1;
	my $token_span = $2 || 1;

	my @token_components;
	my $offset = $position;
	for ( my $i = $offset ; $i < $offset + $token_span ; $i++ ) {
	    push @token_components , $transformed_sentence_tokens[ $i ];
	    $position++;
	}

	my $postprocessed_token_surface = join( " " , map { $_->surface } @token_components );
	while ( $postprocessed_token_surface =~ s/\s+/_/sig ) {}

	# TODO : should we be doing better ?
	my $postprocessed_token_pos = $token_components[ $#token_components ]->pos;
	my $postprocessed_token_abstract_type = $token_components[ $#token_components ]->abstract_type;

	my $marker_start;
	my $marker_end;
	if ( $token_signature eq 'e' ) {
	    $marker_start = '[[';
	    $marker_end = ']]';
	}
	elsif ( $token_signature eq 'a' ) {
	    $marker_start = '((';
	    $marker_end = '))';
	}
	else {
	    $marker_start = '';
	    $marker_end = '';
	}

	push @postprocessed_sentence_tokens , new Web::Summarizer::Token( surface => $postprocessed_token_surface ,
									  pos => $postprocessed_token_pos ,
									  abstract_type => $postprocessed_token_abstract_type );

    }

=cut

=pod
	    # determine whether the current option is known
	    # what is the frequency of this token in our corpus (i.e. LM) ?
	    # note that alternative options are necessarily supported by either the corpus of the target object
	    my $alternative_token_frequency = $token2frequency->{ $token_surface } || 0;
	    my $alternative_token_supported = $token2supported->{ $token_surface } || 0;
	    
	    if ( $token_surface =~ m/^<.+>$/ ) { 
		# we do not modify marker tokens
	    }
	    # a term that is not supported (anything goes as long as its supported) and not known corpus-wide should be dropped
	    elsif ( ! $alternative_token_supported ) {
		
		if ( ! $alternative_token_frequency ) {
		    print STDERR ">> token not known : $token_surface\n";
		    push @unknowns , $token_surface;
		    #$alternative_token = '<unk>';
		    delete $token_alternatives->{ $token_surface_normalized };
		    if ( ! scalar( keys( %{ $token_alternatives } ) ) ) {
			# this is an unknown token and we have no alternatives
			# default to the entire summary vocabulary
			
			$is_unknown = 1;
			
			# TODO : extractive tokens are determined based on existence in reference object ==> if not available in reference object, treat as unknown ?
			$token_alternatives = $this->default_candidates;
		    }
		}
		else {
		    print STDERR ">> token not supported : $token_surface\n";
		}
		
	    }
=cut

1;
