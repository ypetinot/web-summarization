package FactorGraph;

# TODO : create generic bipartite graph class (could be pushed to CPAN later on) ?

# TODO : when a variable connected to a factor gets updated, the corresponding variables must get updated as well (might actually be a prerequisite for message passing algorithm)
# CURRENT : automatically add after method modifiers in FactorGraph ?

use strict;
use warnings;

use Moose::Role;

# random variables (complete set)
#has 'random_variables' => ( is => 'ro' , isa => 'HashRef[RandomVariable]' , required => 1 );
has 'random_variables' => ( is => 'ro' , isa => 'HashRef[RandomVariable]' , init_arg => undef , lazy => 1 , builder => 'create_random_variables' );

# factors
# TODO : is a hash appropriate to store factors ?
has 'factors' => ( is => 'ro' , isa => 'HashRef',
		   init_arg => undef,
		   lazy => 1,
		   builder => 'create_factors',
		   handles => {
		       add_factor => 'set'
		   }
    );
requires 'create_factors';

# featurize
sub featurize {

    my $this = shift;

    my %features;

    foreach my $factor_id (keys %{ $this->factors }) {
	
	my $factor = $this->factors->{ $factor_id };
	my $factor_type = $factor->type;

	my $factor_features = $factor->featurize();

	map {

	    my $factor_feature = $_;

	    # TODO : should we avoid feature repetition ? (i'm thinking that no)
	    my $factor_feature_key = join( "::" , ( ! $factor_type->shared ? $factor_id : () ) , $factor_type->id , $factor_feature );

	    $features{ $factor_feature_key } = $factor_features->{ $factor_feature };

	} keys( %{ $factor_features } );

    }

    return \%features;

}

# TODO : is this always true ?
###with('Instance');

1;
