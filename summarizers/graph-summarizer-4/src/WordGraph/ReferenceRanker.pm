package WordGraph::ReferenceRanker;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Path;

with( 'DMOZ' );

# Note : we are ranking "sentences" ==> our framework operates on sentences but extends beyond previous systems that where limited on sentences that were (up to a certain level) known to be clearly associated with a target object. Our framework aims at allowing a soft notion of association between a reference sentence and an object to summarize.

#extends 'WordGraph::ReferenceOperator';
with 'WordGraph::ReferenceOperator';

# Overall approach : the more I can featurize (preferably in an abstract way) the more we can learn, however it is possible to incrementally featurize the process while leaving other parts non-featuized/optimized, i.e. ad hoc (e.g. the raw search component, which nonetheless could ultimately be featurized and thus optimized).

# CURRENT : must define a (potentially abstract) featurization space that can later support learning
# => assuming : I want to (rank) what type of features should we be able to operate on ? => i.e. what kind on space ?
# => overlap between input and output 

# CURRENT : abstract task definitions in terms of feature spaces object/summary/both

# 1 - Ranking
# CURRENT : if I adopt kernel-based approach, do I need to arbitrarily assign a summary to the target ? => i don't think so because all we need to achieve here is a conditioning of the ranking function on the target object ?
# ==> target object / reference summary - based ranking => same space => ok
# ==> target object / reference object - based ranking => same space => ok
# ==> target object / reference object+summary - based ranking => i don't think object/summary combination necessarily makes sense for ranking, it does though for generation/summarization as a while

# 1 - featurized representation of target object (i.e. signature) => maybe could factor on a "predicted" summary based on features of the target object, making the comparison between the target and reference pairs truly in the same space
# 2 - featurized representation of (reference object + summary)
# 4 - similarity function (maybe asymmetric, i.e. comparing 2 different spaces)

# CURRENT : overall task is to parameterize the summarization process to maximize a given metric, e.g. ROUGE (but could be any other automatic or even manual objective)

# 0 - learn to search (hence I wouldn't even need to learn to re-rank)
#     => parameters are controlling the amount of boost given to terms based on where/how they appear across modalities

# 1 - learn to (re)rank => should be learnable if search is given
#     => generate search lists for a lot of (object,summary) pairs
#     => optimize parameters to maximize ROUGE objective => this is applicable to all steps
#     => featurized representation of summary+object,
#     => fe

# 2 - Adaptation => should be learnable if search is given
#     => featurized representation of raw reference summary (so factors in features of the associaed object)
#     => featurized representation of output summary

# CURRENT : generic view ?
#           => featurized representation of (object,summary pair) => define similarity (energy) based on this representation only => ranking
#           => is there any case where this doesn't apply ?

sub summary_lcs_similarity {

    my $this = shift;
    my $summary_utterance_1 = shift;
    my $summary_utterance_2 = shift;

# TODO : to be removed
=pod
    # TODO : reduce code redudancy
    my @summary_sequence_1 = map { $_->surface } @{ $summary_utterance_1->object_sequence };
    my @summary_sequence_2 = map { $_->surface } @{ $summary_utterance_2->object_sequence };

    return Similarity->lcs_similarity( \@summary_sequence_1 , \@summary_sequence_2 );
=cut

    return $summary_utterance_1->lcs_similarity( $summary_utterance_2 , normalize => 1 , keep_punctuation => 0 );

}

# max count
has 'max_count' => ( is => 'ro' , isa => 'Num' , required => 0 , predicate => 'has_max_count' );

# object featurizer
has '_object_featurizer' => ( is => 'ro' , does => 'Featurizer' , init_arg => undef , lazy => 1 , builder => '_object_featurizer_builder' );

# reversed ranking ?
has 'reversed' => ( is => 'ro' , isa => 'Bool' , default => 0 );

sub _serialization_id {
    
    my $this = shift;
    my $reference_object = shift;
    
    my @parameters = ( $reference_object->url , $this->reversed );

    return [ 'reference-ranked' , \@parameters ];

}

sub _run {

    my $this = shift;
    my $ret = $this->_run_implementation( @_ );

    # Note: we map the original sequence of entries to allow for a stable sort
    my $reversed = $this->reversed;
    my @sorted_sentence_entries = sort { $reversed ? ( $a->[ 1 ] <=> $b->[ 1 ] ) : ( $b->[ 1 ] <=> $a->[ 1 ] ) } @{ $ret };

    # cut off reference set if requested
    if ( $this->has_max_count && $#sorted_sentence_entries >= $this->max_count ) {
	splice @sorted_sentence_entries , $this->max_count;	
    }

    # Note : output ranking
    print STDERR "\n\n*************************************************************************************\n";
    print STDERR "Ranked references:\n";
    map {
	print STDERR join( "\t" , '__RANKED_REFERENCES__' , $_->[ 0 ]->object->url , @{ $_ } ) . "\n";
    } @sorted_sentence_entries;
    print STDERR "*************************************************************************************\n\n";

    return \@sorted_sentence_entries;

}

# TODO : not yet integrated
sub serialize {

    my $full_serialization_path = shift;
    my @sorted_sentence_entries;
    
    # output reference data
    if ( $full_serialization_path ) {

	# TODO : should this be done somewhere else ?
	mkpath dirname( $full_serialization_path );
	
	# TODO : merge into a single statement ?
	open REFERENCE_OUTPUT, ">$full_serialization_path" or die "Unable to create output file ($full_serialization_path): $!";
	binmode(REFERENCE_OUTPUT,':utf8');

	foreach my $sentence_entry (@sorted_sentence_entries) {
	    my $sentence_object = $sentence_entry->[ 0 ];
	    my $sentence_entry_object = $sentence_object->object;
	    my $sentence_entry_score = $sentence_entry->[ 1 ];
	    my $sentence_entry_url = $sentence_entry_object->url;
	    if ( defined( $sentence_entry_score ) ) {
		# Or, we can consider this information as a source, which would turn into 'content'/'context' for sentences directly obtained from the target object or its context
		print REFERENCE_OUTPUT join( "\t" , $sentence_entry_url ,
					     #$category ,
					     $sentence_object , $sentence_entry_score ) . "\n";
	    }
	}

	close REFERENCE_OUTPUT;
	
    }

}

# symmetric
has 'symmetric' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_symmetric_builder' );

# Note : it might become necessary to specify this function as a full-blown class instance
# TODO/Note : the reason for having this here instead of a method/role applied on the (target) object itself is that at different stages of the summarization process we may wish work with a different type of featurization .... but still this should be object-centric ...
has 'object_featurizer' => ( is => 'ro' , does => 'Featurizer' , init_arg => undef , lazy => 1 , builder => '_object_featurizer_builder' );
sub _object_featurizer_builder {
    
    my $this = shift;
    #return $this->_object_featurizer_builder( sub { return $_[ 0 ] } );

    # Note : original version (no weighter)
    ##return new Web::UrlData::Featurizer::ModalityFeaturizer( modality => $this->similarity_field );
    
    # TODO : problably want to make this configurable / also if multiple fields are considered for the featurization, namespaces need to be added (at least for symmetric similarity computations)
    return new Web::UrlData::Featurizer::ModalityFeaturizer( modality => $this->similarity_field , coordinate_weighter => $this->_summary_idf_weighter );

}

# Note : it might become necessary to specify this function as a full-blown class instance
has 'reference_featurizer' => ( is => 'ro' , does => 'Featurizer' , init_arg => undef , lazy => 1 , builder => '_reference_featurizer_builder' );
sub _reference_featurizer_builder {
    my $this = shift;
    return new Web::Summarizer::Sequence::Featurizer;
}

sub _summary_idf_weighter {
    my $this = shift;
    return sub {
	# TODO : parameterize max order
	# TODO : use global count in similarity_field
    	# CURRENT : we need to be able to produce representations that are more than just unigrams
	#return 1 / log( 1 + $this->global_data->field_count_data( 'summary' , 1 , $_[ 0 ] ) );
	return 1 / ( 1 + log( 1 + $this->global_data->global_count( 'summary' , 1 , $_[ 0 ] ) ) );
    };
}

sub object_similarity {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentence = shift;

    my $target_featurized = $target_object->featurize( $this->object_featurizer );
    my $reference_featurized = $this->symmetric ?
	$reference_sentence->object->featurize( $this->object_featurizer ) :
	$reference_sentence->featurize( $this->reference_featurizer );

    my $object_similarity = Vector::cosine( $target_featurized , $reference_featurized );

    return $object_similarity;

}

# TODO : re-enable ?
##__PACKAGE__->meta->make_immutable;

1;
