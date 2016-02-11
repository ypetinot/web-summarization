package Service::Web::UrlNormalizer;

use strict;
use warnings;

use Function::Parameters qw/:strict/;
use LWP::UserAgent;

use Moose;
use namespace::autoclean;

with( 'MongoDBAccess' );
with( 'WebAccess' );

has '_mongodb_collection_mapping_url_canonical' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_mapping_url_canonical_builder' );
sub _mongodb_collection_mapping_url_canonical_builder {
    my $this = shift;
    return $this->get_collection( 'web' , 'url-canonical-mapping' );
}

# use (MongoDB) cache ?
has 'use_cache' => ( is => 'ro' , isa => 'Bool' , default => 0 );

sub read_cache {
    my $this = shift;
    my $url = shift;
    my $url_id_record = $this->_mongodb_collection_mapping_url_canonical->find_one( { _id => $url } );
    return defined( $url_id_record ) ? ( $url_id_record->{ 'node_id' } || $url_id_record->{ 'value' } ) : undef;
}

sub update_cache {
    my $this = shift;
    my $url = shift;
    my $url_normalized = shift;
    # TODO : use _mongodb_id_key instead
    $this->_mongodb_collection_mapping_url_canonical->update( { $this->_mongodb_id_key => $url } , { '$set' => { value => $url_normalized } } , { upsert => 1 } );
}

# CURRENT : add named parameter to enable/disable cache update
method normalize ( $url_raw , :$update_cache = 1 ) {

    my $url_raw = shift;

    my $url_canonical = undef;

    # 1 - check whether we've seen this url before ? => this is not the same as storing the mapping
    if ( $self->use_cache ) {
	$url_canonical = $self->read_cache( $url_raw );
    }

    # 2 - HEAD request to obtain actual URL location
    if ( ! defined( $url_canonical ) ) {

	my $url_head_request = HTTP::Request->new( HEAD => $url_raw );
	my $url_head_response = $self->_request_with_timeout( $url_head_request );
	
	# CURRENT/TODO : what should we do when we get an error ? => discard URL ?
	# CURRENT/TODO : curl --head http://www.bestmanguide.co.uk => HTTP/1.1 405 Method Not Allowd => however URL itself is valid

	if ( defined( $url_head_response ) && ( $url_head_response->is_success || $url_head_response->is_redirect ) ) {
	    
	    my $url_head_response_uri = $url_head_response->base;
	    my $url_head_response_uri_string = $url_head_response_uri->canonical->as_string;
	    
	    $url_canonical = $url_head_response_uri_string;
	    
	    # update cache
	    if ( $update_cache ) {
		$self->update_cache( $url_raw , $url_canonical );
	    }
	    
	}

    }

    return $url_canonical;

}

__PACKAGE__->meta->make_immutable;

1;
