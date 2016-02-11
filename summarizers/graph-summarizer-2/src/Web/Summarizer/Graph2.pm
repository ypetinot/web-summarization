package Web::Summarizer::Graph2;

use Moose;

use Web::Summarizer::Graph2::Definitions;
use Web::Summarizer::Graph2::GistGraph;

use Digest::MD5 qw/md5_hex/;
use Encode qw(encode_utf8);
use JSON;
use List::MoreUtils;

my $DEBUG = 0;

has 'graph' => (is => 'ro', isa => 'Graph', required => 1);
has 'edge2edgeFeatures' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'edge2objectFeatures' => (is => 'rw', isa => 'HashRef', default => sub { {} });
#has 'feature2edge' => (is => 'rw', isa => 'HashRef', default => sub { {} });

sub specialize {

    my $this = shift;
    my $url = shift;
    my $instance_features = shift;
    my $instance_fillers = shift;
    my $instance_features_reference = shift;

    # Is a deep copy necessary ? --> no because we don't update the graph !
    my $instance_graph = $this->graph();

    # Instantiate gist graph for the target URL
    my $gist_graph = new Web::Summarizer::Graph2::GistGraph( url => $url, controller => $this , graph => $instance_graph ,
						   features => $instance_features ,
						   features_reference => $instance_features_reference,
						   fillers => $instance_fillers
	);


    # Now replace slot node with candidate fillers
    # 1 - activate slot nodes (alternate paths + missing filler for slot nodes)
    $gist_graph->activate_nodes();

    return $gist_graph;

}

sub _is_edge_feature {

    my $feature_id = shift;
    
    if ( $feature_id =~ m/^\d+$/ ) {
	return 1;
    }

    return 0;

}

sub _raw_object_feature_id {

    my $feature_id = shift;
    
    my @feature_fields = split /::/, $feature_id;
    my $raw_id = pop @feature_fields;

    return $raw_id;

}

=pod
# Update graph weights
sub _update_graph_weights {
    
    my $this = shift;
    my $weights = shift;
    my $update_ids = shift;
    my $params = shift;

    # map update ids to edges
    my %edge2updated;
    foreach my $update_id (@{ $update_ids }) {
	
	if ( ! _is_edge_feature( $update_id ) ) {
	    $update_id = _raw_object_feature_id( $update_id );
	}
	
	# is this feature active for the current instance ?
	if ( $this->features()->{ $Web::Summarizer::Graph2::Definitions::FEATURES_KEY_EDGE }->{ $update_id } || $this->features()->{ $Web::Summarizer::Graph2::Definitions::FEATURES_KEY_OBJECT } ) {
	    next;
	}
	
	my $edge_mapping = $this->feature2edge()->{ $update_id };
	if ( ! defined( $edge_mapping ) ) {
	    die "Problem: missing edge mapping for feature $update_id ...";
	}

	if ( ! defined( $edge2updated{ $update_id } ) ) {
	    if ( $DEBUG ) {
		print STDERR "Updating edge cost for feature $update_id ...\n";
	    }
	    $this->_update_edge_cost( $weights , $edge_mapping , $params );
	    $edge2updated{ $update_id } = 1;
	}

    }

    if ( $DEBUG ) {
	print STDERR "\n";
    }

};
=cut

# return all possible feature ids (edge + object) for the specified edge
sub _get_features {

    my $this = shift;
    my $edge = shift;
    my $params = shift;

    my ( $from ,$to ) = @{ $edge };

    my @features;

    # 1 - edge features
    my $edge_features = $this->_get_edge_features( $edge );

    # 2 - object features
    my $object_features = $this->_get_object_features( $edge , $params );

    return ( $edge_features , $object_features );

}

# get edge feature ids
sub _get_edge_features {

    my $this = shift;
    my $edge = shift;

    my $edge_key = $this->_edge_key( $edge );

    if ( ! defined( $this->edge2edgeFeatures()->{ $edge_key } ) ) {
	# TODO: should we skip when hitting edges involving virtual nodes ?
	my $edge_feature_data_json = $this->graph()->get_edge_attribute( @{ $edge } , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_FEATURES );
	my $edge_feature_data = {};
	if ( $edge_feature_data_json ) {
	    $edge_feature_data = decode_json( $edge_feature_data_json );
	}
	$this->edge2edgeFeatures()->{ $edge_key } = $edge_feature_data;

    }

    return $this->edge2edgeFeatures()->{ $edge_key };

}

sub _map_object_feature {

    my $this = shift;
    my $feature_id = shift;
    my $edge = shift;

    my ( $from , $to ) = @{ $edge };

    return join("::", $from, $to, "object", $feature_id);

}

sub _map_object_features {

    my $this = shift;
    my $feature_ids = shift;
    my $edge = shift;
   
    if ( ref( $feature_ids ) eq 'ARRAY' ) {
	my @mapped_features = map { $this->_map_object_feature( $_ , $edge ); } @{ $feature_ids };
	return \@mapped_features;
    }
    else {
	my %mapped_features;
	map { $mapped_features{ $this->_map_object_feature( $_ , $edge ) } = $feature_ids->{ $_ }; } keys( %{ $feature_ids } );
	return \%mapped_features;
    }

}

# get object feature ids
sub _get_object_features {

    my $this = shift;
    my $edge = shift;
    my $params = shift;

    my $edge_key = $this->_edge_key( $edge );

#    if ( ! defined( $this->edge2objectFeatures()->{ $edge_key } ) ) {
	my $object_features = $params->{ 'object_features' };
	# my $raw_object_features = $entry_featurized->{ $Web::Summarizer::Graph2::Definitions::FEATURES_KEY_OBJECT };
	# 2 - object features
	# --> simply copy in the current object's features
#	$this->edge2objectFeatures()->{ $edge_key } = $this->_map_object_features( $object_features , $edge );
#    }

#    return $this->edge2objectFeatures()->{ $edge_key };
    return $this->_map_object_features( $object_features , $edge );

}

sub _feature_weight {

    my $weights = shift;
    my $feature_id = shift;

    return ( defined( $weights->{ $feature_id } ) ? $weights->{ $feature_id } : $Web::Summarizer::Graph2::Definitions::WEIGHT_DEFAULT );

}

sub sigmoid {

    my $t = shift;

    return 1 / ( 1 + exp( -1 * $t ) );

}

sub _edge_key {

    my $this = shift;
    my $edge = shift;
    
    if ( $DEBUG ) {
	return join("::", @{ $edge });
    }

    return ( "e_" . md5_hex( encode_utf8( join("::", @{ $edge }) ) ) );

}

no Moose;

1;
