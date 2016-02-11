package MongoDBAccessSingleton;

use strict;
use warnings;

use Config::JSON;
use Function::Parameters qw/:strict/;
use POSIX qw/INT_MAX/;

use MooseX::Singleton;

# host
has 'host' => ( is => 'ro' , isa => 'Str' , required => 0 , default => $ENV{DMOZ_REPOSITORY_HOST} );

# mongodb client
has '_mongodb_client' => ( is => 'ro' , isa => 'MongoDB::MongoClient' , init_arg => undef , lazy => 1 , builder => '_mongodb_client_builder' );
sub _mongodb_client_builder {

    my $this = shift;
    
    my $mongodb_client;

    # read in user credentials
    eval {
	my $user_credentials = Config::JSON->new( $ENV{MONGODB_USER_CONF} )->config;
	# Note : is INT_MAX sufficiently high to avoid disconnections ?
	$mongodb_client = new MongoDB::MongoClient( host => $this->host , query_timeout => -1 ,
						    timeout => INT_MAX , username => $user_credentials->{ 'user' } , password => $user_credentials->{ 'pwd' } );
    };
    if ( $@ ) {
	# TODO : add log message ...
	print STDERR "$@\n";
	exit;
    }

    return $mongodb_client;

}

package MongoDBAccess;

use strict;
use warnings;

use MongoDB;

use Moose::Role;

# data storage implemented using MongoDB

# mongodb _id key
has '_mongodb_id_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => '_id' );

# mongodb client
has '_mongodb_client' => ( is => 'ro' , isa => 'MongoDB::MongoClient' , init_arg => undef , lazy => 1 , builder => '_mongodb_client_builder' );
sub _mongodb_client_builder {
    my $this = shift;
    return MongoDBAccessSingleton->instance->_mongodb_client;
}

# database object cache
# TODO : any value in having this handled by a singleton as well ?
has '_mongodb_databases' => ( is => 'ro' , isa => 'HashRef[MongoDB::Database]' , init_arg => undef , default => sub { {} } );

sub get_collection {
    my $this = shift;
    my $database = shift;
    my $collection = shift;
    if ( ! defined( $this->_mongodb_databases->{ $database } ) ) {
	$this->_mongodb_databases->{ $database } = $this->_mongodb_client->get_database( $database );
    }
    return $this->_mongodb_databases->{ $database }->get_collection( $collection );
}

# low level primitive ?
method set_database_collection_single_field( $database_id , $collection_id , $key , $value ,
					     :$id_key = undef , :$value_key = undef ) {

    $id_key ||= $self->_mongodb_id_key;
    $value_key ||= 'value';

    $self->get_collection( $database_id , $collection_id )->update( { $id_key => $key } ,
							{ '$set' => { $value_key => $value } } ,
							{ upsert => 1 } );

}

# low level primitive ?
method get_database_collection_single_field( $database_id , $collection_id , $key ,
					     :$id_key = undef , :$value_key = undef ) {

    $id_key ||= $self->_mongodb_id_key;
    $value_key ||= 'value';

    my $entry = $self->get_collection( $database_id , $collection_id )->find_one( { $id_key => $key } );

    return defined( $entry ) ? $entry->{ $value_key } : undef;

}

# low level primitive ?
method search_database_collection_single_field( $database_id , $collection_id , $value ,
						:$id_key = undef , :$value_key = undef ) {

    $id_key ||= $self->_mongodb_id_key;
    $value_key ||= 'value';

    my $cursor = $self->get_collection( $database_id , $collection_id )->find( { $value_key => $value } );

    my @results;
    while (my $record = $cursor->next) {
	push @results , $record->{ $id_key };
    }

    return \@results;

}

1;
