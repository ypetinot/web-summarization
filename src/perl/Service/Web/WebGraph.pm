package Service::Web::WebGraph;

use strict;
use warnings;

use Service::Web::UrlNormalizer;
use WebGraph::WebGraphService;

no Carp::Assert;
use Function::Parameters;
use List::MoreUtils qw/uniq/;
use List::Util qw/shuffle/;

use Moose;
use namespace::autoclean;

with( 'Logger' );
with( 'MongoDBAccess' );
# TODO : test non-blocking server implementation => need to add parameter to use framed transport
with( 'Service::ThriftBased' => { port => 8994 , client_class => 'WebGraph::WebGraphServiceClient' } );

has '_mongodb_collection_mapping_url_webgraph_id' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_mapping_url_webgraph_id_builder' );
sub _mongodb_collection_mapping_url_webgraph_id_builder {
    my $this = shift;
    return $this->get_collection( 'url-2-id' , 'mapping' );
}

has '_url_normalizer' => ( is => 'ro' , isa => 'Service::Web::UrlNormalizer' , init_arg => undef , lazy => 1 , builder => '_url_normalizer_builder' );
sub _url_normalizer_builder {
    my $this = shift;
    return Service::Web::UrlNormalizer->new( use_cache => 1 );
}

has '_mapping_node_id_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'node_id' );

method run ( $url , :$max = undef ) {

    # TODO : will we ever need this ?
    #my $mode = shift;

    # 1 - collect list of incoming links from WebGraph service
    my $linking_urls = $self->webgraph_links( $url->as_string , max => $max );

    return $linking_urls;

}

sub webgraph_url_2_id {

    my $this = shift;
    my $url = shift;

    return $this->_webgraph_mapping( $this->_mongodb_id_key , $url , $this->_mapping_node_id_key );

}

sub webgraph_id_2_url {

    my $this = shift;
    my $ids = shift;

    return $this->_webgraph_mapping( $this->_mapping_node_id_key , $ids , $this->_mongodb_id_key , numeric_values => 1 );

}

method _webgraph_mapping( $field , $values , $key , :$numeric_values = 0 ) {

    my $single = ref( $values ) ? 0 : 1;

    my $set = $single ? [ $values ] : $values ;

    # data preparation for numeric values
    if ( $numeric_values ) {
	$set = [ map { int ( $_ ) } @{ $set } ]; 
    }

    # Note : generate (efficient) query
    my $query = { $field => { '$in' => $set } };

    my %mapping;
    # CURRENT/TODO : add error handling / resiliency here
    # => can't get db response, not connected (invalid response header) at /proj/fluke/users/ypetinot/ocelot-working-copy/svn-research/trunk/data/bin/../../src/perl//Service/Web/WebGraph.pm line 80, <STDIN> line 2357577
    my $cursor = $self->_mongodb_collection_mapping_url_webgraph_id->find( $query );
    while (my $webgraph_id_record = $cursor->next) {
	$mapping{ $webgraph_id_record->{ $field } } = $webgraph_id_record->{ $key };
    }

    return $single ? $mapping{ $values } : \%mapping;

}

method webgraph_links ( $url , :$max = undef ) {
    
    # normalize url
    # TODO : should this really be done here ?
    my $url_normalized = $self->_url_normalizer->normalize( $url );

    my $linking_urls;
    if ( defined( $url_normalized ) ) {

	# 1 - map url to web-graph id
	my $url_webgraph_id = $self->webgraph_url_2_id( $url_normalized);
	if ( defined( $url_webgraph_id ) ) {
	    $self->logger->info( "[" . __PACKAGE__ . "] Found WebGraph match for $url: $url_webgraph_id\n" );
	}
	
	# 2 - query webgraph
	if ( defined( $url_webgraph_id ) ) {
	    $linking_urls = $self->_webgraph_query( $url_webgraph_id , max => $max );
	}

    }
    else {

	$self->logger->info( "[" . __PACKAGE__ . "] Unable to retrieve linking urls for unnormalizable url : $url\n" );

    }

    return $linking_urls || [];

}

# Note : for now we don't shuffle by default for performance reason
# TODO : enable shuffling
method _webgraph_query ( $webgraph_id , :$max = undef , :$shuffle = 0 ) {

    # 1 - query webgraph
    # CURRENT : set up tomcat service to access WebGraph => protocol ? 
    # TODO : remove max parameter => find a better way of limiting the number of nodes returned => e.g. sample from an infinite stream until we reach the expected number
    my $linking_nodes = $self->_client->get_linking_nodes( $webgraph_id , 100000 );

    # 3 - map linking nodes to URLs
=pod
	my @_request_linking_nodes = splice @all_linking_nodes , 0 , 50;
	push @linking_urls , values( %{ $this->webgraph_id_2_url( \@_request_linking_nodes ) } );
=cut
    
    # Note : we take a sample of the nodes if requested
    my @linking_nodes_shuffled = $shuffle ? shuffle @{ $linking_nodes } : @{ $linking_nodes };
    my $linking_nodes_process = defined( $max ) ? [ splice ( ( @linking_nodes_shuffled )  , 0 , $max ) ] : \@linking_nodes_shuffled;

    affirm { scalar( @{ $linking_nodes_process } ) <= $max } "At most $max linking nodes should be left at this point" if DEBUG;
    
    my @linking_urls = values( %{ $self->webgraph_id_2_url( $linking_nodes_process ) } );

    # Note : no expensive normalization here, this would be way too expensive => instead allow client to first filter based on its own requirements
    my @linking_urls_normalized = map { URI->new( $_ )->canonical } @linking_urls;

    return \@linking_urls_normalized;

}

__PACKAGE__->meta->make_immutable;

1;
