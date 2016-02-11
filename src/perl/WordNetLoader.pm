package WordNetLoaderSingleton;

use strict;
use warnings;

use Config::JSON;
use POSIX qw/INT_MAX/;

use MooseX::Singleton;

# host
has 'wordnet_query_data' => ( is => 'ro' , isa => 'WordNet::QueryData' , init_arg => undef , lazy => 1 , builder => '_wordnet_query_data_builder' );
sub _wordnet_query_data_builder {

    my $this = shift;
    
    my $WNHOME = Environment->third_party_local;
    my $wn = WordNet::QueryData->new(
	dir => "$WNHOME/dict/",
	verbose => 0,
	#noload => 1
	);
    
    return $wn;

}

1;

package WordNetLoader;

use strict;
use warnings;

use Environment;
use Web::Summarizer::Utils;

use Memoize;
use POSIX;
use WordNet::QueryData;

use Moose::Role;

with( 'Logger' );

# WordNet::QueryData instance
has 'wordnet_query_data' => ( is => 'ro' , isa => 'WordNet::QueryData' , lazy => 1 , builder => '_wordnet_query_data_builder' );
sub _wordnet_query_data_builder {
    return WordNetLoaderSingleton->instance->wordnet_query_data;
}

# CURRENT : configure similarity measure class
# TODO : turn this into a role parameter instead ?
has 'wordnet_similarity_class' => ( is => 'ro' , isa => 'Str' , lazy => 1 , builder => '_wordnet_similarity_class_builder' );
sub _wordnet_similarity_class_builder {
    my $this = shift;
#   return 'WordNet::Similarity::path';
#    return 'WordNet::Similarity::lesk'; # => nowhere near
#    return 'WordNet::Similarity::vector_pairs'; # => no good
    return 'WordNet::Similarity::vector'; # => seems to have some potential
#    return 'WordNet::Similarity::hso'; # => extremely slow and does not seem to exhibit any variation in terms of similarity => eventually probably not worth investigating any further
#    return 'WordNet::Similarity::jcn'; => no good
#    return 'WordNet::Similarity::lch'; => not working ?
#    return 'WordNet::Similarity::lesk';
#    return 'WordNet::Similarity::lin';
#    return 'WordNet::Similarity::path';
#    return 'WordNet::Similarity::random';
#    return 'WordNet::Similarity::res';
#    return 'WordNet::Similarity::wup';
}

# WordNet::Similarity
has 'wordnet_similarity' => ( is => 'ro' , isa => 'WordNet::Similarity' , lazy => 1 , builder => '_wordnet_similarity_builder' );
sub _wordnet_similarity_builder {
    my $this = shift;
    return ( Web::Summarizer::Utils::load_class( $this->wordnet_similarity_class ) )->new ( WordNetLoaderSingleton->instance->wordnet_query_data );
}

# WordNet::Tools
has 'wordnet_tools' => ( is => 'ro' , isa => 'WordNet::Tools' , lazy => 1 , builder => '_wordnet_tools_builder' );
sub _wordnet_tools_builder {
    my $this = shift;
    return WordNet::Tools->new( WordNetLoaderSingleton->instance->wordnet_query_data );
}

# TODO : need another solution for caching
##memoize('semantic_relatedness');
sub semantic_relatedness {

    my $this = shift;
    my $word_a = shift;
    my $word_b = shift;

    my $wordnet_query_data = WordNetLoaderSingleton->instance->wordnet_query_data;
    my $wordnet_similarity = $this->wordnet_similarity;

    my @synsets_a = $wordnet_query_data->queryWord( $word_a );
    my @synsets_b = $wordnet_query_data->queryWord( $word_b );

    # by default we assume synsets to be incompatible
    my $semantic_relatedness = 0;

    if ( scalar( @synsets_a ) && scalar( @synsets_b ) ) {
	
	my $synset_a = $synsets_a[ 0 ] . "#1";
	my $synset_b = $synsets_b[ 0 ] . "#1";

	my $value = $wordnet_similarity->getRelatedness( $synset_a , $synset_b );
	$this->debug( ">> Semantic Relatedness [ $synset_a - $synset_b ] : $value" );

	my ($error, $errorString) = $wordnet_similarity->getError();
	if ( $error ) {
	    print STDERR ">> $errorString\n";
	}
	else {
	    $semantic_relatedness = $value;
	}
	
    }

    return $semantic_relatedness;

}

# TODO : should we implement this as delegation + around ?
sub wordnet_querySense {

    my $this = shift;
    my $string = $_[ 0 ];

    my @senses;

    # TODO : is there a better test to handle special tokens like 'c#' ?
    my $special_string = ( $string =~ m/\#/ && ( scalar( @_ ) == 1 ) );

    if ( defined( $string ) && ! $special_string ) {
	@senses = WordNetLoaderSingleton->instance->wordnet_query_data->querySense( @_ );
    }

    return @senses;

}

1;
