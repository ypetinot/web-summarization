package Decoder::LocalDecoder;

use strict;
use warnings;

use Moose::Role;
###use namespace::autoclean;

with('Decoder');

# cost cache
# TODO : move this up to the main Decoder Role ?
has 'cost_cache' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

sub cost {

    my $this = shift;
    my $output_object = shift;

    my $output_object_key = $output_object->as_string();
    my $cached_cost = $this->cost_cache->{ $output_object_key };
    if ( ! defined( $cached_cost ) ) {
	
	# decompose must be provided for the target class of output object
	# TODO : check for Decomposable ?
	my $output_object_components = $output_object->decompose;
	my $cost = $this->cost_function( $output_object_components );

    }

    return $cached_cost;

}

# CURRENT : integrate EdgeCost with this class
# TODO : should we assume that this is a sequence ?
requires ('component_cost');

###__PACKAGE__->meta->make_immutable;

1;
