package PairwiseFactorType;

# Note : it might be worth renaming this class (and accordingly its sub-classes) to Factor
# Note this is really the function underlying a factor in a factor graph, but does not deal with messages or message passing

# Note : PairwisePotential represents a complex feature - should it also consume the Feature role ?

use strict;
use warnings;

# base class for all (energy-based) (unnormalized) pairwise potentials

use Moose::Role;
#use namespace::autoclean;

# id
# TODO : is this absolutely necessary for FactorType's ?
sub id {
    my $this = shift;
    return ref( $this );
}

# TODO : shouldn't FactorType simply be parameterized by the number of variables attached to it ?
with('Identifiable','FactorType');

our $DEFAULT_FEATURE_WEIGHT = 1;

# model to which this potential belongs (is there a better way to implement back pointers ?)
has 'model' => ( is => 'ro' , does => 'Model' , required => 1 );

# compute features
# TODO : add caching ?
###has 'features' => ( is => 'rw' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_features_builder' );
sub featurize {

    my $this = shift;
    my $body_1 = shift;
    my $body_2 = shift;

    my %features;
    foreach my $feature_definition (@{ $this->feature_definitions() }) {

	my $local_features = $feature_definition->compute( $body_1 , $body_2 );
	map { $features{ $_ } = $local_features->{ $_ }; } keys( %{ $local_features } );

    }

    return \%features;

}

# feature definitions
requires 'feature_definitions';
###has 'feature_definitions' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# value of pairwise potential
# TODO : enforce object ordering / proper object access (method/feature adaptors ?)
sub value {

    my $this = shift;
    my $object1 = shift;
    my $object2 = shift;

    # 1 - get features for the pair of objects connected by this potential
    my $features  = $this->featurize( $object1 , $object2 );

    # 2 - get feature weights
    my $weights = $this->model->feature_weights();

    # 3 - delegate computation
    my $new_value = $this->compute( $features , $weights );

    return $new_value;

}

# default potential computation - linear cost
# TODO : move this to a sub-class ?
sub compute {

    my $this = shift;
    my $features = shift;
    my $weights = shift;

    my $potential_value = 0;
    map { $potential_value += $features->{ $_ } * ( $weights->{ $_ } || $DEFAULT_FEATURE_WEIGHT ); } keys( %{ $features } );

    return $potential_value;

}

###__PACKAGE__->meta->make_immutable;

1;
