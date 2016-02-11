package Modality::Collection;

# Handles field serialization to a single MongoDB collection
# TODO : better package name ?

use strict;
use warnings;

use Moose;
use MooseX::ClassAttribute;
use namespace::autoclean;

with( 'Logger' );
with( 'MongoDBAccess' );

# namespace (database)
has 'namespace' => ( is => 'ro' , isa => 'Str' , required => 1 );

# name (collection)
has 'name' => ( is => 'ro' , isa => 'Str' , required => 1 );

# serializer
has 'serializer' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_serializer' );

# deserializer
has 'deserializer' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_deserializer' );

has '_mongodb_database' => ( is => 'ro' , isa => 'MongoDB::Database' , init_arg => undef , lazy => 1 , builder => '_mongodb_database_builder' );
sub _mongodb_database_builder {
    my $this = shift;
    return $this->_mongodb_client->get_database( $this->namespace );
}

has '_mongodb_collection' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_builder' );
sub _mongodb_collection_builder {
    my $this = shift;
    return $this->_mongodb_database->get_collection( $this->name );
}

# TODO : add flag to force refresh ?
sub update {

    my $this = shift;
    my $key = shift;
    # TODO : add key transformation/adaptation level ? 
    my $entry_key = shift;
    my $entry_value = shift;
    
    # TODO : '$set' only if field does not already exist ?
    # TODO : abstract the reliance on _url_entry_meta through an update method ? Alternatively we could promote the collection and key fields to full fledged fields.
    
    my $entry_key_transformed = $entry_key;
    my $entry_value_transformed = $this->has_serializer ? $this->serializer->( $entry_value ) : $entry_value;

    #$this->logger->trace( 'Updating MongoDB ...' );

    eval {
	$this->_mongodb_collection->update( { $this->_mongodb_id_key => $key } ,
					{ '$set' => {
					    $entry_key_transformed => $entry_value_transformed
					  }
					} ,
					    { upsert => 1 } );
    };

    if ( $@ ) {
	$this->logger->error( "An error occurred during the update to to MongoDB : $@" );
	die;
    }
    #else {
    #$this->logger->trace( 'Successfully updated MongoDB !' );
    #}

    # TODO : should we be returning something ?

}

sub set {

    my $this = shift;
    my $key = shift;
    my $entry = shift;

    foreach my $entry_key (keys( %{ $entry })) {
	my $entry_value = $entry->{ $entry_key };
	# Note : this does not solve the problem of getting undefined values in the first place
	if ( defined( $entry_value ) ) {
	    $this->update( $key , $entry_key , $entry_value );
	}
    }

    # TODO : return refreshed version of the entry ?
    return $entry;

}

sub get {

    my $this = shift;

    # TODO : add key transformation/adaptation level ? 
    my $key = shift;

    my $entry = undef;
    my $raw_entry = $this->_mongodb_collection->find_one( { $this->_mongodb_id_key => $key } );
    
    if ( defined( $raw_entry ) ) {

	$entry = {};
	foreach my $entry_key (keys( %{ $raw_entry } )) {
	    my $entry_value = $raw_entry->{ $entry_key };
	    $entry->{ $entry_key } = ( $this->has_deserializer && $entry_key ne $this->_mongodb_id_key ) ? $this->deserializer->( $entry_value ) : $entry_value;
	}

    }

    return $entry;

}

__PACKAGE__->meta->make_immutable;

1;
