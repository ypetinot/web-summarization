package Model::FactorGraphModel;

use strict;
use warnings;

use Carp;

use Moose::Role;

with('Model');

sub list_features {

    my $this = shift;

    my %features;

    # features are listed by collected features from each factor type in this model
    foreach my $factor_type (@{ $this->factor_types }) {
	map {
	    my $feature = $_;
	    my $feature_id = $feature->id;
	    
	    if ( defined( $features{ $feature_id } ) ) {
		croak "Feature conflict for $feature_id ...";
	    }

	    $features{ $feature_id } = $feature;
	} @{ $factor_type->feature_definitions() };
    }

    return \%features;

}

1;
