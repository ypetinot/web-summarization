package Feature::ServicedFeature;

use Moose::Role;

# TODO : load server information from config file (MooseX::ConfigurationFromFile ?)
#with( ServiceClient => { server_address => "http://mudpuppy.cs.columbia.edu:8989/" } );
with( ServiceClient => { server_address => "http://island2.cs.columbia.edu:8989/" } );

sub feature_request {
    my $this = shift;
    return $this->request( @_ );
}

1;
