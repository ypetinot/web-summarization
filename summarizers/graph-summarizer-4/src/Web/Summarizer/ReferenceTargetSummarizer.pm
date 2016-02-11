package Web::Summarizer::ReferenceTargetSummarizer;

# TODO : remove all WordGraph references

use strict;
use warnings;

use DMOZ::CategoryRepository;
use DMOZ::GlobalData;
use ReferenceTargetInstance;
use WordGraph::ReferenceCollector;
use Web::Summarizer::GeneratedSentence;
use Web::Summarizer::ReferenceTargetSummarizer::Neighborhood;
use Web::Summarizer::SentenceAnalyzer;

use Carp::Assert;

# TODO : turn Summarizer / Web::Summarizer into base classes and turn ReferenceTargetSummarizer into a role ? (right now I'm thinking no)
use Moose;
#use Moose::Role;
use namespace::autoclean;

# TODO
#requires 'decode';

our $default_decoder_class = 'WordGraph::Decoder::ExactDecoder';
our $default_model_class = 'ReferenceTargetPairwiseModel';
our $default_reference_ranker_class = 'WordGraph::ReferenceRanker::NoopRanker';

# serialization directory for reference data
has 'serialization_directory_reference_data' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_serialization_directory_reference_data_builder' );
sub _serialization_directory_reference_data_builder {
    my $this = shift;
    return $this->get_output_directory( "references" );
}

# (inline) system configuration
has 'system_configuration' => ( is => 'ro' , isa => 'Str' , predicate => 'has_system_configuration' );

# dev set ratio
has 'dev_set_ratio' => ( is => 'ro' , isa => 'Num' , default => 0 ); # TODO: this should be a model parameter

# sentence source
has 'sentence_source' => ( is => 'ro' , isa => 'Str' , default => 'references' );

# peform sentence fusion ?
has 'with_summary_fusion' => ( is => 'ro' , isa => 'Bool' , required => 1 , default => 0 );

# TODO : turn this into a configuration parameter
has 'with_hybrid' => ( is => 'ro' , isa => 'Bool' , default => 0 );

=pod
# model class
has 'model_class' => ( is => 'ro' , isa => 'Str' , default => $default_model_class );
has 'model_params' => ( is => 'ro' , isa => 'HashRef[Str]' , default => sub { {} } );

# model
# Note : can be either trained or loaded (how ?)
# TODO : need more appropriate namespace for ReferenceTargetModel
has 'model' => ( is => 'ro' , does => 'ReferenceTargetModel' , init_arg => undef , lazy => 1 , builder => '_model_builder' , handles => [ qw( cost ) ]);
sub _model_builder {
    my $this = shift;
    my %model_params = %{ $this->model_params };
    ###$model_params{ 'object_modalities' } = $target_data->modalities_ngrams;
    # Note : we don't (will we ever ?) need the reference sentence scores inside the reference-target model
    my $model = ( Web::Summarizer::Utils::load_class( $this->model_class ) )->new( %model_params );
    return $model;
}
=cut

# maximum number of reference pairs to consider
# TODO: can the graph be built so that a path can easily be "removed" ? --> probably not
has 'reference_cluster_limit' => ( is => 'ro' , isa => 'Num' , default => 10 );

# repository base
# Note: could be promoted to a parent class in case other summarizers need access to repository data
has 'repository_base' => ( is => 'ro' , isa => 'Str' , init_arg => 'repository-base' , required => 1 );

# global data
# TODO : enable via a role ?
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , required => 1 );
  
# category repository
has 'category_repository' => ( is => 'ro' , isa => 'DMOZ::CategoryRepository' , required => 1 );

# reference collector
has 'reference_collector_class' => ( is => 'ro' , isa => 'Str' , default => 'WordGraph::ReferenceCollector::SignatureIndexCollector' );
has 'reference_collector_params' => ( is => 'ro' , isa => 'HashRef' , required => 0 , predicate => 'has_reference_collector_params' );
has 'reference_collector' => ( is => 'ro' , isa => 'WordGraph::ReferenceCollector' , init_arg => undef , lazy => 1 , builder => '_reference_collector_builder' );
sub _reference_collector_builder {

    my $this = shift;
    
    Web::Summarizer::Utils::load_class( $this->reference_collector_class );
    
    # instantiate collector
    my $reference_collector_params = { global_data => $this->global_data , category_repository => $this->category_repository };

    if ( $this->has_reference_collector_params ) {
	map { $reference_collector_params->{ $_ } = $this->reference_collector_params->{ $_ } } keys %{ $this->reference_collector_params };
    }

    my $reference_collector = ( $this->reference_collector_class )->new( %{ $reference_collector_params } );
    if ( $this->serialization_directory_reference_data ) {
	$reference_collector->serialization_directory( $this->serialization_directory_reference_data )
    }

    return $reference_collector;

}

# target adapter (optional)
# TODO: turn into a role ? if so what base class should it be applied to ? probably not on the Summarizer class
has 'target_adapter_class' => ( is => 'ro' , isa => 'Str' , predicate => 'has_target_adapter_class' );
has 'target_adapter_params' => ( is => 'ro' , isa => 'HashRef' , predicate => 'has_target_adapter_params' , required => 0 );
has 'target_adapter_post_ranking' => ( is => 'ro' , isa => 'Bool' , default => 0 );
has 'target_adapter_post_ranking_oracle' => ( is => 'ro' , isa => 'Str' , predicate => 'has_target_adapter_post_ranking_oracle' );
has 'target_adapter_post_compression' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# reference ranker class / params
# TODO: turn this into an alt name for reference ranker and add necessary build capabilities
has 'reference_ranker_class' => ( is => 'ro' , isa => 'Str' , default => 'WordGraph::ReferenceRanker::NoopRanker' );
has 'reference_ranker_params' => ( is => 'ro' , isa => 'HashRef' , predicate => 'has_reference_ranker_params' , required => 0 );

# reference ranker
has 'reference_ranker' => ( is => 'ro' , isa => 'WordGraph::ReferenceRanker' , init_arg => undef , lazy => 1 , builder => '_reference_ranker_builder' );
sub _reference_ranker_builder {

    my $this = shift;

    Web::Summarizer::Utils::load_class( $this->reference_ranker_class );
    
    # instantiate ranker
    my $reference_ranker_params = { global_data => $this->global_data , category_repository => $this->category_repository };
    if ( $this->has_reference_ranker_params ) {
	map { $reference_ranker_params->{ $_ } = $this->reference_ranker_params->{ $_ } } keys %{ $this->reference_ranker_params };
    }

    my $reference_ranker = ( $this->reference_ranker_class )->new( %{ $reference_ranker_params } );
    if ( $this->serialization_directory_reference_data ) {
	$reference_ranker->serialization_directory( $this->serialization_directory_reference_data )
    }
    
    return $reference_ranker;

}

# target_support_threshold
has 'target_support_threshold' => ( is => 'ro' , isa => 'Num' , default => 0.2 );

sub generate_references {

    my $this = shift;
    my $target_data = shift;

    # *******************************************************************************************************************
    # 1 - collect reference sentences for the target object
    # *******************************************************************************************************************
    my $references_full = $this->collect_references( $target_data );

    # locate ground-truth summary in set of references
    # TODO : this would not work if we had another source of reference sentences ... fix ?
    my @references;
    my $rank_gold;
    my $n_references_full = scalar( @{ $references_full } );
    for ( my $i=0; $i<$n_references_full; $i++ ) {

	my $current_reference_sentence = $references_full->[ $i ];

	if ( $target_data->url_match( $current_reference_sentence->object->url ) ) {
	    $rank_gold = $i + 1;
	    $this->log_summarizer_stat( "rank_gold" , $rank_gold , $n_references_full , $current_reference_sentence );
# CURRENT / NOTE : activate *only* to verify evluation metrics
#		push @references , $current_reference_sentence;
	}
	else {
	    push @references, $current_reference_sentence;
	}

    }

    # *******************************************************************************************************************
    # 2 - filter references
    # *******************************************************************************************************************
    my @filtered_references = grep {
	
	# TODO : turn this into a class => ReferenceFilter
	my $reference_length = $_->length;
	my $reference_category = $_->object->get_field( 'category' , namespace => 'dmoz' );
	my $reference_target_support = 0;
	map { $reference_target_support += ( $_->is_punctuation || $target_data->supports( $_ ) ) ? 1: 0; } @{ $_->object_sequence };

	# TODO : dynamic threshold based on cluster with highest support => support or similarity to signature
	my $relevance = $reference_length ? ( $reference_target_support / $reference_length ) : 0 ;
	$this->logger->info( "Relevance of reference summary ( " . $_->object->url . ") : $relevance / $reference_category" );
	#$relevance > $this->target_support_threshold;
	$this->logger->info( "[TO BE FIXED] - relevance filtering" );
	1;

    } @references;

    # *******************************************************************************************************************
    # 2 - rank reference sentences
    # *******************************************************************************************************************
    # Note : we rank reference sentences instead of reference objects since there could be more than one reference sentence associated with the same object
    # Note : alternatively we could simply think of this as ranking pairs, however the sentences themselves are equipped with a pointer to the object they describe
    $this->logger->info( ">> ranking references" );
    my $ranked_references = $this->reference_ranker->run( $target_data , \@filtered_references );

    # register top ranked reference
    push @{ $this->intermediate_summaries } , [ 'baseline-ranking' , 
						scalar( @{ $ranked_references } ) ? $ranked_references->[ 0 ]->[ 0 ] : $this->_empty_sentence( $target_data ) ];

    # 3 - analyze set of references
    # TODO : any reason to do this right after filtering ?
    {

	$this->state->stats->{ 'reference_count_filtered' } = scalar( @filtered_references );
	for ( my $rank = 1 ; $rank < scalar( @{ $ranked_references } ) ; $rank++ ) {
	    
	    # => compute average LCS at the current rank
	    my $average_lcs = $this->_average_lcs( $ranked_references , $rank );
	    
	    # store stats : how ?
	    $this->state->stats->{ join( '_' , 'homogeneity' , $rank ) } = $average_lcs;
	    $this->log_summarizer_stat( "homogeneity" , $target_data->url , $this->reference_collector_class , $this->reference_ranker_class , $rank , $average_lcs , scalar( @filtered_references ) );
	    
	    # Category Precision / Recall / Distance @ rank
	    my ( $precision_at_rank , $recall_at_rank , $distance_at_rank ) = $this->_prd_at_rank_analysis( $target_data , $ranked_references , $rank );
	    $this->logger->info( join( "\t" , "CPRD" , $precision_at_rank , $recall_at_rank , $distance_at_rank ) );

	}

    }

    # *******************************************************************************************************************
    # 4 - adapt reference entries to target
    # *******************************************************************************************************************
    # Note : need non-overlapping reference set to that terms that should be treated as extractive/other are not mistaken for abstractive terms
    my @adaptation_references = map { [ $_->[ 0 ]->object , $_->[ 0 ] ] } @{ $ranked_references };
    my @references_adapted_ranked;

    if ( $this->has_target_adapter_class ) {

	my @references_adapted_uncompressed;
	my @references_adapted;

	my $reference_adapted_uncompressed;
	my $reference_adapted;

	my $adapted_counter = $this->reference_construction_limit;

	my $need_multiple_neighbor_summaries = 	$this->with_summary_fusion || $this->target_adapter_post_ranking || $this->target_adapter_post_compression;

	my @target_adapters;
	for (my $i=0; $i<=$#adaptation_references; $i++) {
	    
	    my $entry = $adaptation_references[ $i ];
	    my $entry_object = $entry->[ 0 ];
	    my $entry_sentence = $entry->[ 1 ];
	    my $entry_url = $entry_object->url;
	    
	    $this->logger->info( ">> adapting reference => $entry_url" );
	    my @neighborhood = grep { $_ != $entry_object } map { $_->[ 0 ] } @adaptation_references;
	    # TODO : 2-level neighborhood data ? so we can pool together the bulk of the computations
	    my $neighborhood = new Web::Summarizer::ReferenceTargetSummarizer::Neighborhood(
		target => $target_data,
		neighbors => \@neighborhood
		);
	    
	    my $target_adapter = Web::Summarizer::Utils::load_class( $this->target_adapter_class )->new(
		reference_sentence => $entry_sentence ,
		target => $target_data ,
		neighborhood => $neighborhood ,
		( $this->has_output_directory ? ( output_directory => $this->output_directory ) : () ) ,
		%{ $this->target_adapter_params } );
	    
	    my $current_reference_adapted_uncompressed = $target_adapter->adapted_uncompressed;
	    if ( ! defined( $reference_adapted_uncompressed ) ) {
		$reference_adapted_uncompressed = $current_reference_adapted_uncompressed;
	    }
	    push @references_adapted_uncompressed , $current_reference_adapted_uncompressed;

	    push @target_adapters , $target_adapter;

	    # optimization
	    # Note : will be a little bit limitting to test adaptation of multiple references
	    if ( $need_multiple_neighbor_summaries ) {
		# TODO : is this working ?
		if ( --$adapted_counter <= 0 ) {
		    last;
		}
	    }
	    else {
		# Note : only one neighbor summary requested, we can stop right away
		last;
	    }
	    
	}

	# Note : we register the adapted - non-compressed - version of the top-ranked reference
	push @{ $this->intermediate_summaries } , [ 'no-compression' , $reference_adapted_uncompressed || $this->_empty_sentence( $target_data ) ];

	# Note : we perform compression in a separate loop so that - if needed - all adapted references are available to us
	for ( my $i = 0 ; $i <= $#target_adapters ; $i++ ) {

	    my $target_adapter = $target_adapters[ $i ];
	    my $current_reference_adapted = $target_adapter->adapted_compressed( \@references_adapted_uncompressed );
	    if ( ! defined( $reference_adapted ) ) {
		$reference_adapted = $current_reference_adapted;
	    }
	    push @references_adapted , $current_reference_adapted;

	    #if ( ! $this->target_adapter_post_ranking ) {
	    if ( ! $need_multiple_neighbor_summaries ) {
		last;
	    }

	}

	# Note : we register the adapted - compressed - version of the top-ranked reference
	# Note : the adapted+compressed version if the latest version (is this correct ?) 
	push @{ $this->intermediate_summaries } , [ 'compression' , $reference_adapted || $this->_empty_sentence( $target_data ) ]; 

	# TODO : can we do better ?
	my @_references_adapted_ranked;
	# TODO : post ranking should be a array ref of rankers ?
	if ( $this->target_adapter_post_ranking ) {

=pod	    
	    # CURRENT/TODO : we also want to rerank uncompressed adapted references
	    foreach my $rerank_set ( [ 'reranked-oracle' , \@references_adapted , 1 ] , [ 'reranked-oracle-uncompressed' , \@references_adapted_uncompressed , 0 ] ) {
=cut
                $this->logger->info( ">> reranking adapted reference" );
		if ( $this->has_target_adapter_post_ranking_oracle ) {
		    
		    # TODO : can we do this with a ReferenceRanker ?
		    my $ranker = Web::Summarizer::Utils::load_class( $this->target_adapter_post_ranking_oracle )->new( similarity_field => 'summary' );
		    my $_post_ranked_references_adapted = $ranker->run( $target_data , \@references_adapted );
		    
		    my @lcs_overlap = map {
			$target_data->summary_modality->utterance->lcs_similarity( $_ , normalize => 1 , keep_punctuation => 0 );
		    } @references_adapted;
		    
		    # TODO : what is the right metric ? trigrams of lcs overlap ?
		    my @_references_adapted_ranked_oracle = map { $references_adapted[ $_ ] } sort { $lcs_overlap[ $b ] <=> $lcs_overlap[ $a ] } ( 0 .. $#references_adapted );
		    
		    # register top re-ranked summary
		    push @{ $this->intermediate_summaries } , [ 'reranked-oracle' , scalar( @_references_adapted_ranked_oracle ) ?
								$_references_adapted_ranked_oracle[ 0 ] :
								$this->_empty_sentence( $target_data ) ];
		    
		}
		
                @_references_adapted_ranked = sort { $b->score <=> $a->score } @references_adapted;

=pod
	    }
=cut

	}
	else {
	    @_references_adapted_ranked = @references_adapted;
	}
	
	# output adapted references
	# TODO : move all this to a component
	open REFERENCES_ADAPTED , ">" . join( "/" , $this->get_output_directory( 'adapted' ) , 'references.adapted' ) || die "Unable to open file: $!";
	
	# TODO : analyze every single sentence right away => add original as meta ? => this would allow me to select at each stage by target max metric, etc
	@references_adapted_ranked = map {
	    # TODO : add meta-information about the process, how slots were filled, etc.
	    
	    if ( $this->has_sentence_analyzer ) {
		print REFERENCES_ADAPTED join("\t" , $_->object->url , $_->verbalize , $_->score , @{ $this->sentence_analyzer->analyze( $target_data->summary_modality->utterance , $_ ) } ). "\n";
	    }
	    [ $_->object , $_ , $_->score ]

	} @_references_adapted_ranked;
	
	close REFERENCES_ADAPTED;	

    }
    else {

	@references_adapted_ranked = @adaptation_references;

    }

    # *******************************************************************************************************************
    # 3 - truncate reference sentences (if required)
    # *******************************************************************************************************************
    my $reference_cluster_limit = $this->reference_cluster_limit;
    my $ranked_references_truncated;
    if ( $reference_cluster_limit && ( $reference_cluster_limit < scalar( @{ $ranked_references } ) ) ) {
	my @ranked_references_copy = @references_adapted_ranked;
	if ( scalar( @ranked_references_copy ) > $reference_cluster_limit ) {
	    splice @ranked_references_copy , $reference_cluster_limit;
	}
	$ranked_references_truncated = \@ranked_references_copy;
    }
    else {
	$ranked_references_truncated = \@references_adapted_ranked;
    }

    # TODO : return extended stats instead of just the rank of the gold entry ?
    return ( $ranked_references_truncated , $rank_gold );

}

sub collect_references {

    my $this = shift;
    my $target_data = shift;

    my @reference_sentences;

    if ( $this->sentence_source eq 'references' ) {

	my $reference_objects = $this->reference_collector->run( $target_data );

	# 2 - build sentence objects
	foreach my $reference_object ( @{ $reference_objects } ) {
	    
	    # TODO : at this point we could decide to split utterances ?
	    # TODO : an alternative would be to index individual summary sentences

	    my $reference_object_sentence = $reference_object->summary_modality->utterance;
	    # TODO : should we be able to filter out reference objects without summary earlier ?
	    if ( defined( $reference_object_sentence ) ) {
		push @reference_sentences, $reference_object_sentence;
	    }

	}

    }
    elsif ( $this->sentence_source eq 'content' ) {
	
	@reference_sentences = @{ $target_data->content_modality->utterances };

    }
    elsif ( $this->sentence_source eq 'context' ) {
	# TODO : not relevant anymore ?
    }
    else {
	die "Unsupported sentence source " . $this->sentence_source;
    }

    return \@reference_sentences;

}

sub split_references {

    my $this = shift;
    my $references = shift;

    my @preprocessed_reference_sentences = @{ $references };

    my $n_reference_entries = scalar( @preprocessed_reference_sentences );
    my $reference_cluster_limit = $this->reference_cluster_limit;

    if ( $this->dev_set_ratio ) {
	# by default we use 2/3 of the reference data to build the summary graph, and the remaining third to train the model
	if ( ! $reference_cluster_limit ) {
	    $reference_cluster_limit = int( $this->dev_set_ratio * $n_reference_entries );
	}       	
    }
    
    # TODO : add option so that the training and test sets can overlap
    my @reference_sentences_training = @preprocessed_reference_sentences; # used to build the summary graph
    my @reference_sentences_dev; # used to fit the model on top of the summary graph
    if ( $reference_cluster_limit && ( $reference_cluster_limit < $n_reference_entries ) ) {
	@reference_sentences_dev = splice @reference_sentences_training , $reference_cluster_limit;
    }
    else {
	@reference_sentences_dev = @reference_sentences_training;;
    }

    # TODO : can we / should we do better/more ?
    if ( ! scalar( @reference_sentences_training ) ) {
	print STDERR "No reference entry provided ...\n";
    }

    return ( \@reference_sentences_training , \@reference_sentences_dev );

}

# TODO : specify model as role parameter ?
sub summarize {

    my $this = shift;
    my $input = shift;
    
    my $target_data;
    my $reference_entries;
    my $rank_gold = undef;

    if ( ref( $input ) eq 'ARRAY' ) {
	$target_data = $input->[ 0 ];
	$reference_entries = $input->[ 1 ];
    }
    else {
	$target_data = $input;
    }
    
    if ( ! defined( $reference_entries ) ) {
	( $reference_entries , $rank_gold ) = $this->generate_references( $target_data );
    }

    # TODO : remove once we have an external training manager
    my $in_training = shift || 0;

    # generic process for reference-target summarizers
    # specifics to be implemented by consuming classes
        
    # *******************************************************************************************************************
    # 6 - get/train model ( could be a shared model , etc. )
    # *******************************************************************************************************************
    # Note : the model is what's underlying the decoder, since, ultimately, we are training the decoder
    # Note : the decoder ( and by extension the summarize ) specifies minimum requirements for the model ( local vs global , etc. )
    # TODO : should there be a test here or should the training request be made through a separate method ?
    # TODO : ultimately does not belong here, should be handled at a higher lever (main Summarizer role/class ?)
    # Ok while we only perform category-based training
    if ( ! $in_training && $this->does('Trainable') ) {
	
	my @training_set;

	# TODO : this is a category-based approximation , ultimately training should be accomplished at the corpus level
	# TODO : ultimately (ultimately) we should be passing the entire reference corpus together with the target object
	for (my $i=0; $i<=$#{ $reference_entries }; $i++) {

	    my @references_copy = @{ $reference_entries };
	    my $current_reference_entry = splice @references_copy , $i , 1;
	    
	    # for now we use the dev instances as reference set
	    push @training_set , new ReferenceTargetInstance( target_object => $current_reference_entry->[ 0 ] , references => \@references_copy ,
							      target_summary => $current_reference_entry->[ 1 ] );
	}

	$this->info(">> Train model ...");
	$this->train_batch( \@training_set );
	$this->info(">> Done training model ...");

    }

    # TODO : in order to support simpler models , the reference set should become optional => create new intermediate base class ?
    
    # Input: gist-graph G + (URL,path) pairs
    # Output: edge features weights determining the importance (cost) of individual edges
    # Edge cost ~ exponential model
    
    # Learn graph weights
    # Input graph + set of training paths
    # pb --> are the paths still relevant if the graph is custom --> probably not
    # --> create alternative paths at slot locations
    # --> create bypasses
	
    # For the purpose of training weights, we consider slot locations as binary variables ~ however during the testing phase we populate the graph with potential fillers, as well as complete paths from the target URL data (?)
    
    # *******************************************************************************************************************
    # 5 - run summarization process
    # *******************************************************************************************************************

    # switch to testing mode
    # TODO : is this necessary ? by defaul the decoder should/could be in test mode
    $this->test_mode( 1 );

    # TODO : add builder for the id field so that it is automatically derived from the target object
    my $test_instance = new ReferenceTargetInstance( target_object => $target_data , references => $reference_entries );
    my $summary_object = $this->decode( $test_instance->input_object );

    # TODO : should hybrid systems be supported via roles ?
    # Note : not necessary to replace the final output
    if ( $this->with_hybrid ) {
	$this->run_hybrid( $target_data , $summary_object );
    }
    
    # CURRENT : how do we return meta-information/statistics about the summary ?
    return $summary_object;

}

# TODO : enable via a Role ?
# run hybrid systems
sub run_hybrid {

    my $this = shift;
    my $target_data = shift;
    my $summary_predicted = shift;
    
    # CURRENT : should this be passed as a parameter ?
    my $summary_predicted_non_compressed = ( map{ $_->[ 1 ] } grep { $_->[ 0 ] eq 'no-compression' } @{ $this->intermediate_summaries } )[ 0 ];

    # Note : in any case summary_predicted will be inserted at the end of the list of intermediate summaries by run-summarizer-harness
    
    # Note : check length of the title
    my $title_utterance = $target_data->title_modality->utterance;
    if ( $title_utterance && $title_utterance->length ) {

	# TODO : move outside if statement ?
	foreach my $summary_raw_entry ( [ $summary_predicted , 'compression' ] , [ $summary_predicted_non_compressed , 'no-compression' ] ) {
	    
	    my $summary_raw = $summary_raw_entry->[ 0 ];
	    my $summary_raw_index = $summary_raw_entry->[ 1 ];
	    my $summary_raw_string = $summary_raw->raw_string;
	    
	    # Note : check proportion of title that appears in summary_raw
	    my $n_supported = 0;
	    my @title_tokens = grep { ! $_->is_punctuation && ! $_->is_special } @{ $title_utterance->object_sequence };
	    foreach my $title_token (@title_tokens) {
		#if ( $summary_raw->contains( $title_token ) ) {
		#if ( $summary_raw->supports_regex( $title_token->as_regex ) ) {
		my $title_token_regex = $title_token->as_regex;
		if ( $summary_raw_string =~ $title_token_regex ) {
		    $n_supported++;
		}
	    }
	    
	    my $title_support = $n_supported ? $n_supported / scalar( @title_tokens ) : $n_supported;
	    if ( $title_support < 1 ) {
		
		# hybrid - title - replacement
		{
		    my $summary_hybrid_title_replacement = ( $title_support < 0.5 ) ? $title_utterance : $summary_raw;
		    push @{ $this->intermediate_summaries } , [ join( '-' , 'hybrid-title-replacement' , $summary_raw_index ) ,
								$summary_hybrid_title_replacement ];
		}
		
		# hybrid - title - concatenation
		{
		    my $summary_hybrid_title_concatenation = new Web::Summarizer::GeneratedSentence(
			raw_string => join( ' | ' , $title_utterance->verbalize , $summary_raw_string ) ,
			object => $target_data ,
			score => 0 );

		    push @{ $this->intermediate_summaries } , [ join( '-' , 'hybrid-title-concatenation' , $summary_raw_index ) ,
								$summary_hybrid_title_concatenation ];
		}
		
	    }
	    
	}
	
    }

}

# => compute average LCS at the current rank
sub _average_lcs {

    my $this = shift;
    my $ranked_references = shift;
    my $rank = shift;

    my $n_references = scalar( @{ $ranked_references } );
    affirm { $rank < $n_references } 'rank must be within the limits of the number of references' if DEBUG;

    my $average_lcs = 0;
    my $count = 0;
    for ( my $i=0; $i<=$rank; $i++ ) {
	for ( my $j=$i+1; $j<=$rank; $j++ ) {
	    $average_lcs += $ranked_references->[ $i ]->[ 0 ]->lcs_similarity( $ranked_references->[ $j ]->[ 0 ] , normalize => 1 , keep_punctuation => 0 );
	    $count++;
	}
    }

    affirm { $count != 0 } 'rank request cannot lead to an empty count' if DEBUG;
    $average_lcs /= $count;

    return $average_lcs;

}

sub _prd_at_rank_analysis {

    my $this = shift;
    my $target_data = shift;
    my $ranked_references = shift;
    my $rank = shift;

    my $precision_at_rank = 0;
    my $recall_at_rank = 0;
    my $distance_at_rank = 0;

    return ( $precision_at_rank , $recall_at_rank , $distance_at_rank );

}

# TODO : promote ?
sub _empty_sentence {
    my $this = shift;
    my $target_object = shift;
    return new Web::Summarizer::GeneratedSentence( raw_string => '' , object => $target_object , score => 0 );
}

with('Web::Summarizer');

# Note : cannot be made immutable since this (and subclasses) are consuming roles dynamically
###__PACKAGE__->meta->make_immutable;

1;
