package WikipediaResolver;

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use StringNormalizer;

use WebService::Solr;

our $DEBUG = 1;

my $solr_backend = WebService::Solr->new( 'http://southpaw.cs.columbia.edu:8080/solr/dbpedia-ontology-mapping' );

=pod
# resolves Wikipedia match to a generic type
sub type {

    my $that = shift;
    my $wikipedia_entry = shift;

    my $data = undef;

    if ( $wikipedia_entry ) {

	my @url_components = split /\//, $wikipedia_entry;
	$data = $cache_dbpedia->get( join("/", 'http://dbpedia.org/resource/', $url_components[$#url_components] ) );

    }

    return $data || [];

}
=cut

# look for the longest wikipeda match
sub resolve {

    my $that = shift;
    my $string = shift;

    my $result = [];

    my @string_tokens = split /\s+/, $string;
    my $title_string = join("_", @string_tokens);
    my $query_string = join("+", @string_tokens);
    
    my $response = $solr_backend->search( "id:\"http\:\/\/dbpedia.org\/resource\/$title_string\" title:$query_string" );
    my @results;
    for my $doc ( $response->docs ) {
	push @results, [ $doc->value_for( 'id' ) , $doc->value_for( 'title' ) , $doc->value_for( 'value' ) ];
    }
    
    my $matching_entries = $that->_get_matching_entries( $string , \@results );
    
    if ( scalar( @{$matching_entries} ) ) {
	
	my @final_result = map { 
	    
	    my ($concept_id,$concept_title,$concept_types) = @{ $_ };
	    
	    my $concept_name = $concept_title;
	    my $disambiguation = undef;
	    
	    if ( $concept_title =~ m/^(.+) \((.+)\)$/ ) {
		$concept_name = $1;
		$disambiguation = $2;
	    }
	    
	    [ $concept_id , $concept_name , $disambiguation , $concept_types ];
	    
	} @{ $matching_entries };
	
	$result = \@final_result;
	
    }

    return $result;
   
}

# extract matching entries from result list (preserving order)
sub _get_matching_entries {

    my $that = shift;
    my $target_string = shift;
    my $raw_set = shift;

    my @matching_entries;

    foreach my $entry (@{ $raw_set }) {
	
	my $entry_url = $entry->[ 0 ];
	my $entry_title = $entry->[ 1 ];
	my $entry_data = $entry->[ 2 ];

	my @url_fields = split /\//, $entry_url;
	my $slug = pop @url_fields;
	$slug =~ s/\_/ /g;

	my $normalized_target_string = StringNormalizer::_normalize( $target_string );

	if ( $entry_title =~ m/^$normalized_target_string(?: \(.+\))?$/si ) {
	    print STDERR "[Wikipedia Resolver] found match for $target_string --> $entry_title / $entry_url\n";
	    push @matching_entries, $entry;
	}

    }

    return \@matching_entries;

}

no Moose;

1;
