package WordGraph::ReferenceCollector::IndexCollector;

use strict;
use warnings;

use Function::Parameters qw/:strict/;
use List::Util qw/min/;
use Text::Trim;
use URI::Escape;
use WebService::Solr;
use WebService::Solr::Query;

use Moose;
use namespace::autoclean;

extends 'WordGraph::ReferenceCollector';
with( 'DMOZ' );

# n
has 'n' => ( is => 'ro' , isa => 'Num' , default => 20 );

# solr collection
has 'solr_collection' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_solr_collection_builder' );
sub _solr_collection_builder {
    return 'odp-index';
}

# solr base
has 'solr_base' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_solr_base_builder' );
sub _solr_base_builder {
    my $this = shift;
    return join( '/' , 'http://barracuda.cs.columbia.edu:8080/solr' , $this->solr_collection );
}

# solr client
has '_solr_client' => ( is => 'ro' , isa => 'WebService::Solr' , init_arg => undef , lazy => 1 , builder => '_solr_client_builder' );
sub _solr_client_builder {
    my $this = shift;
    my $solr = WebService::Solr->new( $this->solr_base );
    return $solr;
}

=pod
# request field
has 'target_query_field' => ( is => 'ro' , isa => 'Str' , default => 'content.segmented' );
=cut

# query field
has 'index_query_field' => ( is => 'ro' , isa => 'Str' , required => 1 );

sub _term_boosting {

    my $this = shift;
    my $term = shift;
    my $tf = shift;

    # 1 - get corpus rank ?
    my $corpus_frequency = $this->global_data->global_count( 'summary' , 1 , $term );

    # 1 - global count
    my $global_count = $this->global_data->global_count( 'summary' , 1 );

    return ( $corpus_frequency / ( $tf * $global_count ) );

}

sub _query_index {

    my $this = shift;
    my $terms = shift;

    # TODO : add support for boosting, etc. ?

#    my %term_tfs;
#    map { $term_tfs{ $_ }++ } @{ $terms };
#    my $query_string = $this->index_query_field . ":(" . join( " " , map { uri_escape($_) . "^" . min( 1.0 , $this->_term_boosting( $_ , $term_tfs{ $_ } ) ) } keys( %term_tfs ) ) . ")";
#    my $query_string = $this->index_query_field . ":(" . join( " " , map { uri_escape($_) . "^" . min( 1.0 , 1.0 ) } keys( %term_tfs ) ) . ")";
    my $query_string = $this->index_query_field . ":(" . join( " " , map { uri_escape_utf8($_) . "^" . $terms->{ $_ } } keys( %{ $terms } ) ) . ")";

    return $this->_query_solr( $query_string , max => $this->n );

}

method _query_solr ( $query_string , :$max ) {

    my $response = $self->_solr_client->generic_solr_request( 'select' , { q => $query_string , rows => $max } );
    
    # iterate over response entries
    my @reference_objects;
    
    if ( $response->ok ) {
	
	foreach my $response_entry ( $response->docs ) {
	    
	    my $response_entry_url = $response_entry->value_for( 'url' );
	    my $response_entry_category = $response_entry->value_for( 'category' );
	    my $response_entry_description = $response_entry->value_for( 'description' );

	    # TODO : the reference object instantiation can not be handled by _load_object
	    my $reference_object = Category::UrlData->load_url_data( $response_entry_url );
	    if ( ! defined( $reference_object ) ) {
		print STDERR "[TODO] all data for $response_entry_url should now be removed from the datastore ...\n";
		next;
	    }
	    
	    # TODO : this should be removed once the correct indexing is in place
	    if ( ! $reference_object->has_field( 'summary' , namespace => 'dmoz' ) ) {
		$reference_object->set_field( 'summary' , $response_entry_description , namespace => 'dmoz' );
	    }
	    if ( ! $reference_object->has_field( 'category' , namespace => 'dmoz' ) ) {
		$reference_object->set_field( 'category' , $response_entry_category , namespace => 'dmoz' );
	    }
	    
	    push @reference_objects, $reference_object;
	    
	}
	
    }
    
    return \@reference_objects;

}

sub _run {
    
    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    # 1 - query index using request field as query
    # TODO : need a wrapper around this instead of providing a default here
    my $field_data = $target_object->utterances->{ $this->target_query_field } || [];
    my $query_field_content = undef;
    if ( ref( $field_data ) ) {
	if ( ref( $field_data ) eq 'ARRAY' ) {
	    $query_field_content = join ( " " , @{ $field_data } );
	}
	else {
	    die "Query field type not supported ...";
	}
    }
    else {
	$query_field_content = $field_data;
    }
    # TODO : add escaping ?
    while ( $query_field_content =~ s/\p{Punct}+/ /sg ) {}
    
    my @_terms = grep { length( $_ ) } map{ trim $_; } ( split /\s+/ , $query_field_content );
# Note : taking a subset of terms (maybe the 10 most frequent ?) seems to work well in bringing back "functionally similar" pages.
# CURRENT : reason seems to be that these terms (at least for the page I'm working with right now) are navigational links ==> navigational links are probably a good source of functional terms
#   DB<4> p Dumper( $terms )
#$VAR1 = [
#          'Home',
#          'Registration',
#          'Register',
#          'Hotels',
#          'Registration',
#          'Policies',
#          'Convention',
#          'Rules',
#          'Weapon',
#          'Policies'
#    ];
# Other potential solution: use as query words terms that are important in the pages (using corpus statistics as reference) but which are not named entities, adjectives, adverbs, etc. (and also that occur often enough in summaries).
    splice @_terms , 10;

=pod
    my $modalities_unigrams = $target_object->get_all_modalities_unigrams;
    my @_terms = grep { scalar( keys( %{ $modalities_unigrams->{ $_ } } ) ) > 1 } keys( %{ $modalities_unigrams } );
=cut
    
    # TODO : consider negative boosting ? => if regular boosting strategy does not work
    # https://wiki.apache.org/solr/SolrRelevancyFAQ
    # q =  foo^100 bar^100 (*:* -xxx)^999

    return $this->_query_index( \@_terms );

}

__PACKAGE__->meta->make_immutable;

1;

=pod
    # 2 - iterate over response entries
#    my @reference_objects;

    my $q = Thread::Queue->new();
    my $q_out = Thread::Queue->new();

    my $n_threads = 10;
    for ( my $i=0; $i<$n_threads; $i++ ) {
	threads->create( sub {
	    while (defined(my $item = $q->dequeue())) {
		my ( $response_entry_url , $response_entry_category ) = @{ $item };
		$q_out->enqueue( $reference_object );
	    }
			 } );
    }

    foreach my $response_entry ( $response->docs ) {

	my $response_entry_url = $response_entry->value_for( 'url' );
	my $response_entry_category = $response_entry->value_for( 'category' );

	$q->enqueue( [ $response_entry_url , $response_entry_category ] );

    }

# TODO : need to install the latest version of Thread::Queue ?
#    $q->end();
    for ( my $i=0; $i<$n_threads; $i++ ) {
	$q->enqueue( undef );
    }

    # Loop through all the threads
    foreach my $thr (threads->list()) {
        $thr->join();
    }

    my @reference_objects;
    #= values( %references );
    while (defined(my $item = $q_out->dequeue_nb())) {
	push @reference_objects, $item;
    }
=cut

=pod
    my %query_params;
    foreach my $term (keys( %term_tfs )) {
    
       my $q = WebService::Solr::Query->new( { foo => { -boost => [ 'bar', '2.0' ] } } );
       $query_params{ $this->index_query_field }{ $term } "^1.0"; } keys( %term_tfs ) );
    
    }

    my $query = WebService::Solr::Query->new( { $this->index_query_field => $query_string } );
    my %options = ( rows => 50 );
    my $response = $this->_solr_client->search( $query, \%options );
=cut
