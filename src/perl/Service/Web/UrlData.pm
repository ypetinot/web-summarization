package Service::Web::UrlData;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with( ServiceClient => { server_address => join( ":" , $ENV{ SERVICES_BASE } , $ENV{ SERVICE_PORT_URLDATA } ) } );

sub get_field {
    my $this = shift;
    return $this->_url_data_service_request( 'url-data' , @_ );
}

sub global_count {
    my $this = shift;
    return $this->_url_data_service_request( 'global-count' , @_ );
}

sub _url_data_service_request {

    my $this = shift;
    my $method = shift;

    # forward request to service
    my $service_response = $this->request( $method , @_ );

    return $service_response;

}

1;
