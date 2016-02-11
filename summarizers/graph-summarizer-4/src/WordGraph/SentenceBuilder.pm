package WordGraph::SentenceBuilder;

use strict;
use warnings;

# TODO : no complaint if I remove this, but crashes nonetheless ... why ?
use Web::Summarizer::Graph2::Definitions;

use Moose;
use namespace::autoclean;

extends 'Web::Summarizer::SentenceBuilder';

# TODO : remove
=pod
# enable pre-computed slots (overrides any setting of the other slot-related flags)
has 'enable_precomputed_slots' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# enable adjective slots
has 'enable_adjective_slots' => ( is => 'rw' , isa => 'Bool' , default => 1 );

# enable adverb slots
has 'enable_adverb_slots' => ( is => 'rw' , isa => 'Bool' , default => 1 );

# ignore punctuation
has 'ignore_punctuation' => ( is => 'rw' , isa => 'Bool' , default => 1 );

# reference corpus
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , required => 1 );

# (associated data) object
has 'object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 0 );
=cut

sub token_transformer {

    my $this = shift;
    my $token_sequence = shift;

# TODO : remove - no longer necessary since this class is no longer responsible for preprocessing the inputs of the fusion process - this is now achieved through adaptation
=pod
    # 1 - get raw elements
    # TODO: is there a better way to handle the default values ?
    my @transformed_token_sequence = grep {
	# TODO: change this ?
	if ( ! $this->enable_adjective_slots ) {
	    ( $_->[ 3 ] || '' ) ne 'SLOT_ADJECTIVE';
	}
	# TODO: change this ?
	elsif ( ! $this->enable_adverb_slots ) {
	    ( $_->[ 3 ] || '' ) ne 'SLOT_ADVERB';   
	}
	elsif ( $this->ignore_punctuation ) {
	    ( $_->[ 0 ] !~ m/^\p{Punct}$/ );
	}
	else {
	    1;
	}
    }
    map {
	# are precomputed slots disabled ?
	if ( ! $this->enable_precomputed_slots ) {
	    $_->[ 3 ] = '';
	}
	$_;
    } @updated_token_sequence;
=cut

    return \@transformed_token_sequence;

}

=pod
sub compute_specificity {

    my $this = shift;
    my $data_object = shift;
    my $token_data = shift;

    my $token_surface = $token_data->[ 0 ];
    my $token_pos = $token_data->[ 1 ] || '';
    my $token_sequence = $token_data->[ 2 ] || '';
    my $token_abstract_type = $token_data->[ 3 ] || '';

    # Determinants are never target-specific
    if ( $token_pos =~ /^DT$/sio ) {
	return 0;
    }

    # compute frequency of token in reference object
    my $reference_frequency = scalar( keys %{ $this->data_extractor()->frequency( $data_object , $token_surface ) || {} } );
    
###    # compute frequency of token in corpus
    my $target_frequency = $this->global_data->global_count( 'content.rendered' , 1 , $token_surface );

    # By default we assume full target-specificity
    my $specificity = 1;

    # == --> 0
    # reference > target --> ~ 1
    # target < reference --> ~ 0
    if ( $reference_frequency == $target_frequency ) {
	$specificity = 0;
    }
    elsif ( $reference_frequency > $target_frequency ) {
	$specificity = $target_frequency ? _sigmoid( $reference_frequency / $target_frequency ) : 1;
    }
    elsif ( $target_frequency < $reference_frequency ) {
	$specificity = _sigmoid( $target_frequency / $reference_frequency );
    }

    # TODO: in terms of graph construction, we will have to remove any node that has full target specificity
    return $specificity;

}
=cut

sub _sigmoid {

    my $value = shift;

    return 1 / ( 1 + exp( -1 * $value ) );

}

__PACKAGE__->meta->make_immutable;

1;
