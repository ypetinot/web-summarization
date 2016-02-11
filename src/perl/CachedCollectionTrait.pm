#package CachedCollection::Meta::Attribute::Trait::Cached;
package CachedCollectionTrait;

use strict;
use warnings;

#use Moose::Role;
use MooseX::Role::Parameterized;

# CURRENT : override reader ?

has cache_namespace => (
    is => 'ro' , 
    isa => 'Str',
    required => 1
);

has cache_name => (
    is => 'ro' ,
    isa => 'Str',
    required => 1
);

has cache_serializer => (
    isa => 'CodeRef' ,
    required => 0 ,
    default => sub { sub { return $_[ 0 ]; } }
);

has cache_deserializer => (
    isa => 'CodeRef' ,
    required => 0 ,
    default => sub { sub { return $_[ 0 ]; } }
);

has 'entry_data_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'data' );

has '_cache_collection' => ( is => 'ro' , isa => 'Modality::Collection' , init_arg => undef , lazy => 1 , builder => '_cache_collection_builder' );
sub _cache_collection_builder {
    my $this = shift;
    my $collection = new Modality::Collection( namespace => $this->cache_namespace , name => $this->name ,  serializer => $this->serializer , deserializer => $this->deserializer );
    return $collection;
}

# CURRENT : how to specify these if class used as a Trait ?
# => data_generator should be a builder ?
requires( 'key_generator' );
requires( 'data_generator' );

# TODO : instead of having a unique key, we could create a sub-class of Modality::Collection that aims at caching a single (key,value) pair.
sub get_value {
    
    my $this = shift;
    my $refresh = shift || 0;
    
    my $raw_data = undef;
    
    my $cacheable = 1;
    my $cache_key = $this->key_generator;
    my $raw_data_key = $this->entry_data_key;
    
    # check to see if data is available from cache
    if ( $cacheable && ! $refresh ) {
	my $cache_entry = $this->_cache_collection->get( $cache_key );
	if ( defined( $cache_entry ) ) {
	    $raw_data = $cache_entry->{ $raw_data_key };
	}
    }
    
    if ( ! defined( $raw_data ) ) {
	$raw_data = $this->data_generator;
	if ( ! defined( $raw_data ) ) {
	    print STDERR "[" . __PACKAGE__ . "] Unable to generate field {" . $this->cache_namespace . "/" . $this->name . "} for $cache_key ...\n";
	}
	# Note : we choose to cache only if the raw data is not undefined (i.e. got generated successfull)
	elsif ( $cacheable ) {
	    # update cache
	    $this->_cache_collection->set( $cache_key , { $raw_data_key => $raw_data } );
	}
    }
    
    return $raw_data;
    
}

1;
