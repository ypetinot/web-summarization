package Cache::MongoDB;

# MongoDB-based cache

use strict;
use warnings;

use Moose;

use MongoDB;

our $connection;

sub BEGIN {
    eval {
	$connection = MongoDB::Connection->new( host => 'southpaw.cs.columbia.edu' , port => 27017 );
    };
}

# Underlying Mongo db
has 'database' => (is => 'ro', isa => 'Str', required => 1);

# Underlying collection
has 'collection' => (is => 'ro', isa => 'Str', required => 1);

sub get {

    my $this = shift;
    my $key = shift;

    my $value = undef;

    my $handle = $this->_get_collection_handle();
    if ( $handle ) {
	
	my $result = $handle->find_one( { _id => $key } );
	if ( defined( $result ) ) {
	    $value = $result->{ _value };
	}
	else {
	    # error handling ?
	}
	
    }

    return $value;

}

sub set {

    my $this = shift;
    my $key = shift;
    my $value = shift;

    my $handle = $this->_get_collection_handle();
    if ( $handle ) {
	my $result = $handle->save( { _id => $key , _value => $value } );
    }

}

sub _get_db_handle {

    my $this = shift;

    if ( !defined( $connection ) ) {
	print STDERR "Unable to connect to MongoDB ...\n";
	return undef;
    }

    my $db_name = $this->database();
    return $connection->$db_name;

}

sub _get_collection_handle {

    my $this = shift;

    my $db_handle = $this->_get_db_handle();
    if ( !defined( $db_handle ) ) {
	print STDERR "Unable to find cache database ...\n";
	return undef;
    }

    my $collection_name = $this->collection();
    return $db_handle->$collection_name;

}

no Moose;

1;
