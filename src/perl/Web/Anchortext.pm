package Web::Anchortext;

use strict;
use warnings;

use Service::Web::WebGraph;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

with( 'Logger' );
with( 'Web::Object' );

# Web-graph service
has '_webgraph_service' => ( is => 'ro' , isa => 'Service::Web::WebGraph' , init_arg => undef , lazy => 1 , builder => '_webgraph_service_builder' );
sub _webgraph_service_builder {
    my $this = shift;
    return Service::Web::WebGraph->new;
}

sub basic {

    my $this = shift;
    my $url_data = shift;
    my $link = shift;

    # basic text extraction
    my $link_text_basic = $link->[ 2 ]->as_text;

    return $link_text_basic;

}

sub sentence {

    my $this = shift;
    my $url_data = shift;
    my $link = shift;

    # sentence extraction
    my $link_element = $link->[ 2 ];
    my $link_element_parent_text = $link_element->parent->as_text;
    if ( length ( $link_element_parent_text ) > 1000 ) {
	$this->logger->warn( "Found dubious extended anchortext segment, will default to basic anchortext: $link_element_parent_text" );
	return $this->basic( $url_data , $link );
    }
    my $link_text_sentence = $link_element_parent_text;

    return $link_text_sentence;

}

# Note : this is where filtering happens
# TODO : should we offer an option to filter out internal links ?
method segment( :$sentences = 1 , :$basic = 0 , :$max = undef , :$max_per_host = undef , :$filter_domains = [ 'dmoz.org' ] ) { 

    # TODO : can we optimize this => cache regex ?
    my $filter_domains_regex_string = join( "|" , @{ $filter_domains } );
    my $filter_domains_regex = length( $filter_domains_regex_string ) ? qr/$filter_domains_regex_string/si : undef;
    
    # TODO : can we do better ?
    my $type = $sentences ? 'sentence' : 'basic';

    my @result;
	
    # 1 - obtain list of linking URLs
    # TODO : query with both normalized and regular URL and merge lists => problem => we need to have access to more data about the target URL ...
    my $linking_urls = $self->_webgraph_service->run( $self->url , max => $max );
    my $linking_urls_count = scalar( @{ $linking_urls } );

    # 2 - process earch URL independently
    my %host2seen;
    for ( my $i = 1 ; $i <= $linking_urls_count ; $i++ ) {
	
	my $linking_url = $linking_urls->[ $i - 1 ];

	$self->logger->debug( "Processing linking URL ($i/$linking_urls_count): $linking_url" );

	# filter based on domains
	if ( defined( $filter_domains_regex_string ) && $linking_url =~ $filter_domains_regex_string ) {
	    $self->logger->debug( "Skipping linking URL from unwanted domain : $linking_url" );
	    next;
	}

	# we only consider URLs using an http(s) scheme
	# TODO : could we test for this earlier ? (would avoid the unnecessary creation of a URI object)
	if ( ref( $linking_url ) !~ m/^URI\:\:http/si ) {
	    $self->logger->debug( "Skipping linking URL using non http scheme : $linking_url" );
	    next;
	}

	# TODO : ideally the host extraction should be handled by Category::UrlData => need to modify load_url_data to accommodate this 
	my $linking_url_host = $linking_url->host;
	if ( defined( $max_per_host ) && ( ( ++ $host2seen{ $linking_url_host } ) > $max_per_host ) ) {
	    $self->logger->debug( "Skipping linking URL from overlinking host : $linking_url_host" );
	    next;
	}

	# 4 - normalize linking URLs (?)
	###my @linking_urls_normalized = uniq grep { defined( $_ ); } map { $this->_url_normalizer->normalize( $_ ); } @linking_urls;
	
	# Note : delay loading until this point to avoid rendering irrelevant/unwanted linking URLs
	# map linking URL to a UrlData instance
	my $linking_url_data;
	eval {
	    $linking_url_data = Category::UrlData->load_url_data( $linking_url );
	};

	# 2.2 - we filter URLs that are no longer valid
	if ( ! defined( $linking_url_data ) ) {
	    $self->logger->debug( "Unable acquire data for linking URL : $linking_url" );
	    next;
	}

	# 2.3 - extract links to target
	# TODO : similarly we should be getting links for all variations of the target URL
	my $links = $linking_url_data->get_links( target => $self->url );

	# 3.2 - process each link independently
	my %seen;
	my $count = 0;
	foreach my $link (@{ $links }) {

	    # 3.2.1 - extract raw string based on requested type
	    my $raw_string = $sentences ? $self->sentence( $linking_url_data , $link ) : $self->basic( $linking_url_data , $link );

	    # 3.2.2 - mark this string as seen
	    # Note : we only consider unique strings for a given linking URL
	    if ( $seen{ $raw_string } ) {
		next;
	    }
	    $seen{ $raw_string }++;

	    my $raw_string_id = join( '.' , __PACKAGE__ , $type , $linking_url , $count++ );
	    
	    # TODO : we don't build sequences at this stage, however there would be value in being able to identify which linking URL provides a particular segment
            #push @result , new Web::Summarizer::StringSequence( raw_string => $raw_string , object => source_id => $raw_string_id );

	    # TODO : is there a way to avoid this problem altogether ?
	    if ( ! utf8::is_utf8( $raw_string ) ) {
		$self->logger->debug( "Skipping non-utf8 anchortext string: $raw_string" );
		next;
	    }
	    
	    utf8::encode( $raw_string );
	    push @result , $raw_string;
	
	}
	
    }

    # TODO : should we filter out duplicates ?
    return \@result;

}

__PACKAGE__->meta->make_immutable;

1;
