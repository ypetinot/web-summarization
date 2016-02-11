package CachedCollection;

# CURRENT : can this handle the serialization of structured fields ?
#           => with serializer/deserializer => 
#           => without serializer/deserializer ?

use strict;
use warnings;

# TODO : can we avoid having a dependency on the Modality:: namespace ?
use Modality::Collection;

use MooseX::Role::Parameterized;

parameter namespace => (
    isa => 'Str',
    required => 1
);

parameter name => (
    isa => 'Str',
    required => 1
);

# CURRENT : compatible with multiple fields (name) ?
parameter serializer => (
    isa => 'CodeRef',
    required => 0,
    default => sub { sub { return $_[ 0 ]; } }
);

parameter deserializer => (
    isa => 'CodeRef',
    required => 0,
    default => sub { sub { return $_[ 0 ]; } }
);

role {

    my $p = shift;
    my $namespace = $p->namespace;
    my $name = $p->name;
    my $serializer = $p->serializer;
    my $deserializer = $p->deserializer;

    has 'entry_data_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'data' );

    has '_cache_collection' => ( is => 'ro' , isa => 'Modality::Collection' , init_arg => undef , lazy => 1 , builder => '_cache_collection_builder' );
    method _cache_collection_builder => sub {
	my $this = shift;
	my $collection = new Modality::Collection( namespace => $namespace , name => $name ,  serializer => $serializer , deserializer => $deserializer );
	return $collection;
    };

    # CURRENT : how to specify these if class used as a Trait ?
    # Note / TODO : the serializer/deserializer components could be specified as required methods
    requires( 'key_generator' );
    requires( 'data_generator' );

    # TODO : instead of having a unique key, we could create a sub-class of Modality::Collection that aims at caching a single (key,value) pair.
    method get_data => sub {

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
		print STDERR "[" . __PACKAGE__ . "] Unable to generate field {$namespace/$name} for $cache_key ...\n";
	    }
	    # Note : we choose to cache only if the raw data is not undefined (i.e. got generated successfull)
	    elsif ( $cacheable ) {
		# update cache
		$this->_cache_collection->set( $cache_key , { $raw_data_key => $raw_data } );
	    }
	}

	return $raw_data;

    };

};

1;
