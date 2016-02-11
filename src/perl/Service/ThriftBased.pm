package Service::ThriftBased;

use warnings;

use Data::Dumper;
use POSIX qw/LONG_MAX/;
use Thrift;
use Thrift::BinaryProtocol;
use Thrift::Socket;
use Thrift::BufferedTransport;
use Thrift::FramedTransport;

# TODO : find a better solution (see below)
use Web::Summarizer::Utils;

use MooseX::Role::Parameterized;
#use MooseX::Types::Perl qw( PackageName );

parameter port => (
    # TODO : there might exist a more appropriate type/trait for port numbers ?
    isa => 'Num',
    required => 1
);

parameter host => (
    isa => 'Str',
    required => 0,
    default => $ENV{ SERVICE_HOST }
);

parameter client_class => (
    # TODO : is there a more appropriate type/trait for module names ? => MooseX::Types::Perl ?
    isa => 'Str',
    #isa => 'PackageName',
    required => 1,
);

parameter reconnection_attempts => (
    isa => 'Num',
    default => 10
);

# TODO : remove once all server use TFramedTransport by default ?
parameter use_framed_transport => (
    isa => 'Bool',
    default => 0
);

role {

    my $p = shift;
    my $reconnection_attempts = $p->reconnection_attempts;
    my $use_framed_transport = $p->use_framed_transport;

    has '_socket' => ( is => 'ro' , isa => 'Thrift::Socket' , init_arg => undef , lazy => 1 , builder => '_socket_builder' );
    method _socket_builder => sub {
	my $this = shift;
	#$this->logger->debug( 'Building thrift socket with port number : ' . $p->port );
	my $socket = new Thrift::Socket( $p->host , $p->port );
	# Note : 10 mins timeout seems reasonable, if the server takes longer and/or the client blocks, something has to be fixed
	$socket->setRecvTimeout( 10 * 60 * 1000 );
#	$socket->setRecvTimeout( LONG_MAX );
	return $socket;
    };
    
    has '_transport' => ( is => 'ro' , isa => 'Thrift::Transport' , init_arg => undef , lazy => 1 , builder => $use_framed_transport ? '_framed_transport_builder' : '_buffered_transport_builder' );
    method _buffered_transport_builder => sub {

	my $this = shift;
	my $transport = new Thrift::BufferedTransport($this->_socket,1024,1024);

	# TODO : should we do this at a later time ?
	my $sleep_period = 1;
	my $attempts = 0;
	my $transport_ok = 0;

	# TODO : should we improve this, i.e. do we want to try to reconnect forever ?
	# TODO : ideal sleep strategy ?
	while ( ! $transport_ok && ( $attempts++ <= $reconnection_attempts ) ) {

	    eval {
		$transport->open;
	    };

	    if ( $@ ) {
		$this->logger->warn( "Unable to open connection to thrift server: " . Dumper( $@ ) );
		$sleep_period *= 10;
		$this->logger->warn( "Will reattempt to connect in $sleep_period seconds ..." );;
		sleep $sleep_period;
	    }
	    else {
		$transport_ok = 1;
	    }

	}

	return $transport;

    };

    method _framed_transport_builder => sub {
	
	my $this = shift;
	my $transport = new Thrift::FramedTransport($this->_socket,1024,1024);

	return $transport;

    };

    has '_protocol' => ( is => 'ro' , isa => 'Thrift::BinaryProtocol' , init_arg => undef , lazy => 1 , builder => '_protocol_builder' );
    method _protocol_builder => sub {
	my $this = shift;
	return new Thrift::BinaryProtocol($this->_transport);
    };

    has '_client' => ( is => 'ro' , isa => $p->client_class , init_arg => undef , lazy => 1 , builder => '_client_builder' );
    method _client_builder => sub {
	my $this = shift;
	# TODO : remove dependency on Web::Summarizer::Utils::load_class => promote utility to a more generic module ?
#	return Web::Summarizer::Utils::load_class( $p->client_class )->new($this->_protocol);
	return $p->client_class->new($this->_protocol);
    };

    with( 'Logger' );

};

1;
