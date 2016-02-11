package DBPedia;

use strict;
use warnings;

use StringNormalizer;

use Function::Parameters qw/:strict/;

use Moose::Role;

with( 'Logger' );
with( 'MongoDBAccess' );

# TODO[base] => can we specify the collection directly by making MongoDBAccess a parameterized role ?
has '_mongodb_collection_dbpedia_types' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_dbpedia_types_builder' );
sub _mongodb_collection_dbpedia_types_builder {
    my $this = shift;
    return $this->get_collection( 'dbpedia' , 'types' );
}

has '_types_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'types' );
has '_surface_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'surface' );


sub set_types {

    my $this = shift;
    my $string = shift;
    my $types = shift;

    my $normalized_string = $this->_string_normalizer( $string );
    
    # TODO : add method to MongoDBAccess to abstract the query construction
    $this->_mongodb_collection_dbpedia_types->update( { $this->_mongodb_id_key => $normalized_string } , { '$set' => {
	$this->_types_key => $types,
	$this->_surface_key => $string									   }
						      } , { upsert => 1 } );

}

# TODO : to be added to the db initialization process => db.types.createIndex( { _id: "text" } )
method get_types ( $_string , :$phrase = 0 ) {

    my $string = $self->_string_normalizer( $_string );

    # query using search
    #my $query = { '$text' => { '$search' => "$string" } };

    # exact query
    my $query_exact = { $self->_mongodb_id_key => $string };
    my $entry = $self->_type_query_one( $query_exact );

=pod
    # TODO : add '^' and '$' ?
    # TODO : retrieve based on prefix and then filter
    my @string_tokens = ( split /\s+/ , $string );

    if ( !defined( $entry ) && $#string_tokens > 0 ) {

	my $string_regex_simple = '^' . $string_tokens[ 0 ]; 
	my $query_regex_simple = $self->_generate_regex_query( $string_regex_simple );
	
	my $string_regex_full = '^' . join( '[ \,\.]*' , @string_tokens ) . '$';
	my $query_regex_full = $self->_generate_regex_query( $string_regex_full );
       
	#|| $self->_type_query( $query_regex );
	$entry = $self->_type_query_best( $query_regex_simple , $string_regex_full );

    }
=cut

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
    my $query = shift;

    # Note : if I ever need to retrieve all possible matches, all an extra method parameter (e.g. 'all')
    my $entry = $this->_mongodb_collection_dbpedia_types->find_one( $query );

    return $entry;

}

sub _type_query_best {

    my $this = shift;
    my $query_regex = shift;
    my $query_regex_full = shift;

    # Note : if I ever need to retrieve all possible matches, all an extra method parameter (e.g. 'all')
    $this->logger->debug( "Querying DBPedia (best) : $query_regex_full" );
    my $cursor = $this->_mongodb_collection_dbpedia_types->find( $query_regex );
    my $query_regex_full_object = qr/$query_regex_full/;
    while (my $record = $cursor->next) {
	my $record_key = $record->{ $this->_mongodb_id_key };
	if ( $record_key =~ m/$query_regex_full_object/si ) {
	    $this->logger->debug( "DBPedia (best) => found $record_key" );
	    return $record;
	}
    }

    $this->logger->debug( "DBPedia (best) => <no match>" );
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

1;
