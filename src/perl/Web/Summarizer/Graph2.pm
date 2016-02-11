package Web::Summarizer::Graph2;

use Moose;

use Web::Summarizer::Graph2::Definitions;

use Digest::MD5 qw/md5_hex/;
use Encode qw(encode_utf8);
use JSON;
use List::MoreUtils;

my $DEBUG = 0;

has 'graph' => (is => 'ro', isa => 'Graph', required => 1);
has 'edge2edgeFeatures' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'edge2objectFeatures' => (is => 'rw', isa => 'HashRef', default => sub { {} });

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
    my $object_features = $params->{ 'object_features' };

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
