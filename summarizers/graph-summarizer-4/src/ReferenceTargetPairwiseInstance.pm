package ReferenceTargetPairwiseInstance;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends('ReferenceTargetInstance');

sub featurize {
 
    my $this = shift;

    my %features;
    foreach my $configuration ( @{ $this->configurations } ) {
	
	my $configuration_features = $configuration->featurize;
	map { $features{ $_ }+= $configuration_features->{ $_ }; } keys( %{ $configuration_features } );

    }

    return \%features;
   
}

# configurations
has 'configurations' => ( is => 'ro' , isa => 'ArrayRef[ReferenceTargetPairwiseFactorGraph]' , required => 1 );

# TODO : should this belong to a role ?
sub compute_unnormalized_probability {
    
    my $this = shift;

    my $unnormalized_probability = 0;

    # Note : the unnormalized probability factors into the unnormalized probability of each individual configurations => take the product of those
    # TODO : should we make some provision for the cases where all the references are unrelated ? => no
    map { $unnormalized_probability *= $_->compute_unnormalized_probability } @{ $this->configurations };
    
    return $unnormalized_probability;
    
}

__PACKAGE__->meta->make_immutable;

1;
