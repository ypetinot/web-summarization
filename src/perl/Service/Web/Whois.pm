package Service::Web::Whois;

use strict;
use warnings;

no Carp::Assert;

use Moose;
use namespace::autoclean;

with( 'Logger' );
with( 'MongoDBAccess' );

# TODO : to guarantee the maximum rate of access to Whois resources, implement service using a single threaded server
with( 'Service::ThriftBased' => { port => 8993 , client_class => 'Whois::WhoisServiceClient' } );

has '_mongodb_collection_whois' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_whois_builder' );
sub _mongodb_collection_whois_builder {
    my $this = shift;
    return $this->get_collection( 'web' , 'whois' );
}

has '_mapping_node_id_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'node_id' );

method run ( $domain ) {

    # 1 - collect list of incoming links from WebGraph service
    my $linking_urls = $self->webgraph_links( $url->as_string , max => $max );

    return $linking_urls;

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
    my $cursor = $self->_mongodb_collection_mapping_url_webgraph_id->find( $query );
    while (my $webgraph_id_record = $cursor->next) {
	$mapping{ $webgraph_id_record->{ $field } } = $webgraph_id_record->{ $key };
    }

    return $single ? $mapping{ $values } : \%mapping;

}

method whois_query ( $domain_string ) {

    # 1 - query whois service
    my $whois_data = $self->_client->get_whois_data( $domain_string );

    # 2 - pre-normalization / parsing ?
    # TODO
    
    return $whois_data;

}

__PACKAGE__->meta->make_immutable;

1;
