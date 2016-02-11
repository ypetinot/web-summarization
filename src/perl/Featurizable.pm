package Featurizable;

use strict;
use warnings;

use Moose::Role;

# features cache - key is the unique id of the Featurizer instance which produced the associated set of features
has '_features_cache' => ( is => 'ro' , isa => 'HashRef[Str]' , init_arg => undef , default => sub { {} } );

sub featurize {

    my $this = shift;
    my $featurizer = shift;

    my $featurizer_key = $featurizer->id;

    if ( ! defined( $this->_features_cache->{ $featurizer_key } ) ) {
	# Note : ultimately we would really want to have the featurizer be a role that gets applied on the featurizable object
	my $features = $featurizer->run( $this );
	$this->_features_cache->{ $featurizer_key } = $features;
    }

    return $this->_features_cache->{ $featurizer_key };

}

1;
