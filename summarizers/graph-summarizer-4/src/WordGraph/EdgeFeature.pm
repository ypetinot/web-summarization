package WordGraph::EdgeFeature;

use Moose;
use namespace::autoclean;

# id
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 );

with('Feature');

# params
has 'params' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

sub cache_key {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    # TODO: include graph id asap
    my $cache_key = join( "::" , $edge->[0] , $edge->[1] , $instance->id );

    return $cache_key;

}

# value
sub compute {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    my %features;
    
    my $feature_key = $this->id();

    # 1 - collect common resources
    my $common_resources = $this->get_resources( $graph , $edge , $instance );

    # 2 - compute node-level features (if required)
    my $source_features = $this->value_node( $graph , $edge , $instance , $common_resources , 0 );
    if ( $source_features ) {
	$this->_update_features( "source" , \%features , $source_features );
    }

    my $sink_features = $this->value_node( $graph , $edge , $instance , $common_resources , 1 );
    if ( $sink_features ) {
	$this->_update_features( "sink" , \%features , $sink_features );
    }

    # 3 - compute edge-level features (if required)
    my $edge_features = $this->value_edge( $graph , $edge , $instance , $common_resources , $source_features , $sink_features );
    if ( $edge_features ) {
	$this->_update_features( "edge" , \%features , $edge_features );
    }

    return \%features;

}

# default implementation of get_resources
sub get_resources {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    return $this->_get_resources( $graph , $edge , $instance );

}

# CURRENT : feature generation code as role applied onto Category::UrlData instances ?

# default implementation of _get_resources
sub _get_resources {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    # nothing
    return {};

}

sub _update_features {

    my $this = shift;
    my $domain = shift;
    my $features_ref = shift;
    my $add_features = shift;

    # TODO : can I somehow merge these two branches ?
    if ( ref( $add_features ) ) {
	foreach my $add_feature_id ( keys( %{ $add_features } ) ) {
	    my $feature_key = $this->key( $domain , $add_feature_id );
	    $features_ref->{ $feature_key } = $add_features->{ $add_feature_id };
	}
    }
    else {
	my $feature_key = $this->key( $domain );
	$features_ref->{ $feature_key } = $add_features;
    }

}

# feature key
sub key {

    my $this = shift;
    my $domain = shift;

    return feature_key( $domain , $this->id() , @_ );

}

sub feature_key {
    
    return join( "::" , map { if ( ref( $_ ) ) { $_->[ 0 ] } else { $_ } } @_ );

}

# default feature normalizer (no normalization)
sub _normalizer {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;

    return 1;

}

__PACKAGE__->meta->make_immutable;

1;
