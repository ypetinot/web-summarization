package ServiceClient;

use strict;
use warnings;

use JSON::RPC::Legacy::Client;

#use Moose::Role;
use MooseX::Role::Parameterized;

parameter server_address => (
    isa => 'Str',
    required => 1
    );

role {

    my $p = shift;
    my $_server_address = $p->server_address;

    # server client
    has 'server_client' => ( is => 'ro' , isa => 'JSON::RPC::Legacy::Client' , builder => '_build_server_client' , lazy => 1 );
    method "_build_server_client" => sub {
	
	my $this = shift;
	
	my $client = new JSON::RPC::Legacy::Client;
	$client->{ 'json' }->convert_blessed( 1 );
	$client->ua->timeout( 10000000000 );
	
	return $client;

    };

    method "request" => sub {

	my $this = shift;
	my $request_type = shift;
	my $request_params = \@_;
	
	my $callobj = {
	    method  => $request_type,
	    params  => $request_params,
	};
    
	my $uri = $_server_address;
	my $res = $this->server_client()->call( $uri , $callobj );
	
	my $payload = undef;
	
	if($res) {
	    if ($res->is_error) {
		print STDERR "Error : ", $res->error_message->{'message'} . "\n";
	    }
	    else {
		# TODO: enable transfer of blessed references
		$payload = $res->result;
	    }
	}
	else {
	    print STDERR $this->server_client()->status_line . "\n";
	}
	
	return $payload;

    };

};

1;
