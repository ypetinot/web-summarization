package Feature::ModalityConditional;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use Similarity;
use Vocabulary;

use List::Util qw/max min/;
use Memoize;
use Statistics::Basic qw(:all);

# id
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return join( "::" , 'modality-conditional' , $this->modality->id() );
}

# ngram order for source features
has 'ngram_order' => ( is => 'ro' , isa => 'Num' , required => 1 );

# TODO : create intermediate super-class for (Modality,Token) aggregate features
# mode
has 'mode' => ( is => 'ro' , isa => 'Str' , required => 1 );

with('Feature::ModalityFeature','Feature::ServicedFeature');

my $COMMON_CONDITIONAL_PROBABILITIES = 'conditional-probabilities';

sub _get_resources {

    my $this = shift;
    my $instance = shift;

    my %common_resources;

    # request conditional features for the current (instance,modality) pair
    # TODO : again, make sure this gets cached
    $common_resources{ $COMMON_CONDITIONAL_PROBABILITIES } = $this->_conditional_features( $instance );

    return \%common_resources;

}

sub _value_node {

    my $this = shift;
    my $feature = shift;
    my $instance = shift;

    my $raw_modality_conditional_features = $this->_get_resources( $instance )->{ $COMMON_CONDITIONAL_PROBABILITIES };

    # process conditional probabilities
    my $node_normalized = lc( $feature );
    my $node_raw_modality_conditional_features = $raw_modality_conditional_features->{ $node_normalized };
    my $node_modality_conditional_features = {};
    if ( defined( $node_raw_modality_conditional_features ) ) {

	my @chi_square_scores = map { $_->[ 2 ] } @{ $node_raw_modality_conditional_features };
	my @conditional_probabilities = map { $_->[ 3 ] } @{ $node_raw_modality_conditional_features };

	foreach my $feature_type ( [ 'chi-square-score' , \@chi_square_scores ] , [ 'conditional-probabilities' , \@conditional_probabilities ] ) {
	    $node_modality_conditional_features->{ join( "-" , $feature_type->[ 0 ] , "max" ) } = max( @{ $feature_type->[ 1 ] } );
	    $node_modality_conditional_features->{ join( "-" , $feature_type->[ 0 ] , "min" ) } = min( @{ $feature_type->[ 1 ] } );
	    $node_modality_conditional_features->{ join( "-" , $feature_type->[ 0 ] , "mean" ) } = mean( @{ $feature_type->[ 1 ] } )->query;
	    $node_modality_conditional_features->{ join( "-" , $feature_type->[ 0 ] , "median" ) } = median( @{ $feature_type->[ 1 ] } )->query;
	}

    }

    return $node_modality_conditional_features;

}

=pod
sub _value_edge {

    my $this = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $source_features = shift;
    my $sink_features = shift;
    my $modality = shift;
    
    my %features;

    # product / average (probably already handled by any linear learning model I might choose to use)
    foreach my $function ( \&_product , \&_average ) {
	foreach my $feature_key (keys %{ $source_features }) {
	    $features{ $feature_key } = $function->( $source_features->{ $feature_key } || 0 , $sink_features->{ $feature_key } || 0 );
	}
    }

    return \%features;

}
=cut

sub _product {

    my $a = shift;
    my $b = shift;

    return $a * $b;

}

sub _average {

    my $a = shift;
    my $b = shift;

    return ( $a + $b ) / 2;

}

memoize("_conditional_features");
sub _conditional_features {

    my $this = shift;
    my $instance = shift;

    # 1 - get modality data
    my ( $modality_data , $mapping , $mapping_surface ) = $instance->get_modality_data( $this->modality , $this->ngram_order , 1 , 1 );
    
    # 2 - map features to their global ids
    my %mapped_modality_data;
    map { $mapped_modality_data{ $mapping_surface->{ $_ } } = $modality_data->{ $_ } } keys( %{ $modality_data } );

    # 3 - get conditional features
    # TODO : make sure we have caching enable for the modality feature request ...
    my $modality_conditional_features = $this->feature_request( 'get_conditional_features' , $this->modality , \%mapped_modality_data );

    # 4 - post-process conditional features
    # Note : the features returned contain potentially overlapping conditional probabilities. These probabilities can be combined in several ways and this needs to be done at the calling level.
    my %collected_modality_conditional_features;
    my $post_processed_modality_conditional_features = {};
    foreach my $summary_object (keys( %{ $modality_conditional_features } )) {
	if ( ! defined( $collected_modality_conditional_features{ $summary_object } ) ) {
	    $collected_modality_conditional_features{ $summary_object } = [];
	}
	map { push @{ $collected_modality_conditional_features{ $summary_object } } , $_ } @{ $modality_conditional_features->{ $summary_object } };
    }
    
    return \%collected_modality_conditional_features;

}

sub compute {

    my $this = shift;
    my $object = shift;
    my $sequence = shift;

    # TODO : add support for higher-order n-grams
    my $appearance_conditional = 0;
    my $sequence_ngrams = $sequence->get_ngrams( 1 );
    my $sequence_ngrams_count = scalar( @{ $sequence_ngrams } );
    
    for (my $i=0; $i<$sequence_ngrams_count; $i++) {

	my $current_ngram = $sequence_ngrams->[ $i ];
	my $local_appearance_conditional = $this->_value_node( $current_ngram , $object );

    }

    my $feature_key = join( "::" , $this->id , $this->modality->id );
    
    return { $feature_key => $appearance_conditional };
    
}

__PACKAGE__->meta->make_immutable;

1;
