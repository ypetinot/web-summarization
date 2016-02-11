package Freebase;

# TODO : promote code that is shared with DBPedia => add a parameterized Role, e.g. TypeSource

use strict;
use warnings;

use StringNormalizer;

use Function::Parameters qw/:strict/;

use Moose::Role;

with( 'Logger' );
with( 'MongoDBAccess' );

# key normalization ?
# TODO : for DBPedia this should be turned on
has 'key_normalization' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# source id
has 'source_id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'freebase' );

# TODO[base] => can we specify the collection directly by making MongoDBAccess a parameterized role ?
has '_mongodb_collection_types' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_types_builder' );
sub _mongodb_collection_types_builder {
    my $this = shift;
    return $this->get_collection( $this->source_id , 'types' );
}

has '_mongodb_collection_surfaces' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_surfaces_builder' );
sub _mongodb_collection_surfaces_builder {
    my $this = shift;
    return $this->get_collection( $this->source_id , 'surfaces' );
}

has '_types_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'types' );
has '_surface_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'surface' );

sub set_surfaces {

    my $this = shift;
    my $string = shift;
    my $types = shift;

    my $normalized_string = $this->key_normalization ? $this->_string_normalizer( $string ) : $string;

    # TODO : add method to MongoDBAccess to abstract the query construction
    $this->_mongodb_collection_surfaces->update( { $this->_mongodb_id_key => $normalized_string } , { '$set' => {
	$this->_types_key => $types,
	$this->_surface_key => $string									   }
					      } , { upsert => 1 } );

}

sub set_types {

    my $this = shift;
    my $string = shift;
    my $types = shift;
    
    # TODO : add method to MongoDBAccess to abstract the query construction
    $this->_mongodb_collection_types->update( { $this->_mongodb_id_key => $string } , { '$set' => {
	$this->_types_key => $types,
	$this->_surface_key => $string									   }
						      } , { upsert => 1 } );

}

# TODO : to be added to the db initialization process => db.types.createIndex( { _id: "text" } )
method get_types ( $_string , :$phrase = 0 ) {

    my $string = $self->key_normalization ? $self->_string_normalizer( $_string ) : $_string;

    # query using search
    #my $query = { '$text' => { '$search' => "$string" } };

    # exact query
    my $query_exact = { $self->_mongodb_id_key => $string };
    my $entry = $self->_type_query_one( $query_exact );

    my $types = defined( $entry ) ? $entry->{ $self->_types_key } : undef;
    
    return $types;

}

sub _generate_regex_query {

    my $this = shift;
    my $string_regex = shift;

    return { $this->_mongodb_id_key => { '$regex' => $string_regex , '$options' => 'mi' } };

}

sub _type_query_one {

    my $this = shift;
    my $collection = shift;
    my $query = shift;

    # Note : if I ever need to retrieve all possible matches, all an extra method parameter (e.g. 'all')
    my $entry = $collection->find_one( $query );

    return $entry;

}

sub _type_query_best {

    my $this = shift;
    my $query_regex = shift;
    my $query_regex_full = shift;

    # Note : if I ever need to retrieve all possible matches, all an extra method parameter (e.g. 'all')
    $this->logger->debug( "Querying " . $this->source_id . " (best) : $query_regex_full" );
    my $cursor = $this->_mongodb_collection_types->find( $query_regex );
    my $query_regex_full_object = qr/$query_regex_full/;
    while (my $record = $cursor->next) {
	my $record_key = $record->{ $this->_mongodb_id_key };
	if ( $record_key =~ m/$query_regex_full_object/si ) {
	    $this->logger->debug( $this->source_id . " (best) => found $record_key" );
	    return $record;
	}
    }

    $this->logger->debug( $this->source_id . " (best) => <no match>" );
    return undef;

}

# TODO : precompute alternate forms for entities and index in MongoDB
# TODO : punctuation in the middle of a word should probably not be replaced by a space
sub _string_normalizer {

    my $this = shift;
    my $string_raw = shift;

    my $normalized_string = $string_raw;

    # remove all punctuation
    $normalized_string =~ s/\p{Punct}+/ /sg;

    # basic normalization
    $normalized_string = StringNormalizer::_normalize( $normalized_string );

    # TODO : replace spaces by underscores ? => does not seem necessary

    return $normalized_string;

}

sub map_string_to_entities {

    my $this = shift;
    my $string = shift;

    my $normalized_string = $this->key_normalization ? $this->_string_normalizer( $string ) : $string;

    # lookup string
    my $query_exact = { $this->_mongodb_id_key => $normalized_string };
    my $entry = $this->_type_query_one( $this->_mongodb_collection_surfaces , $query_exact );

    my $entities = defined( $entry ) ? $entry->{ $this->_types_key } : undef;
    
    return $entities;

}

sub map_entity_to_types {

    my $this = shift;
    my $string = shift;

    # lookup string
    my $query_exact = { $this->_mongodb_id_key => $string };
    my $entry = $this->_type_query_one( $this->_mongodb_collection_types , $query_exact );

    my $types = defined( $entry ) ? $entry->{ $this->_types_key } : undef;
    
    return $types;

}

1;
