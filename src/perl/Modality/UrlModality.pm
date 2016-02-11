package Modality::UrlModality;

# Controls generation of data associated with the URL string itself (i.e not considering the URL as a pointer to other resources)

use strict;
use warnings;

use JSON;
use Net::Whois::Raw;
use Text::Trim;

$Net::Whois::Raw::OMIT_MSG = 1;
#$Net::Whois::Raw::CACHE_DIR = "/home/ypetinot/research/pwhois/";
#$Net::Whois::Raw::CACHE_TIME = 60 * 24 * 365;

use Moose;
use namespace::autoclean;

extends( 'Modality::SingleStringSequenceModality' );

# CURRENT : collect entities by running whois on target URL and keeping only entities that match the content of the page

# CURRENT/TODO : introduce the notion of master/slave modalities ? => slave modalities (weaker confidence) can only introduce entities/candidates that are also supported by a master modality

# CURRENT : only use WHOIS data to generate named entities ? each with a count of 1 => possible ?
# => 1 - override _named_entities_builder
# => 2 - where do we store the WHOIS data ?

# CURRENT/TODO : separate storage for WHOIS data
# => collection in web database ? => url_whois
sub generate_whois_data {

    my $this = shift;

    my $host_name = $this->object->host;
    my @host_components = split /\./ , $host_name;

    # TODO : store raw WHOIS data ? => service
    if ( ! $this->object->has_field( 'whois' , namespace => 'web' ) ) {

	my @whois_data;
	
	# TODO : is there a better way ?
	# Note : the code below will fail for multi-part TLD's
	my %seen;
	while ( scalar( @host_components ) >= 2 ) {
	    my $host_substring = join( '.' , @host_components );
	    eval {
		#my $arrayref = get_whois( $host_substring , undef, 'QRY_ALL' );
		my $arrayref = whois( $host_substring , undef, 'QRY_ALL' );
		if ( $arrayref ) {
		    map {
			my $entry_text = $_->{ 'text' };
			utf8::encode( $entry_text );
			my @entry_text_lines = grep {
			    # TODO : filter out to avoid ICANN sneaking into the list of entities ? >> 'Domain Status: ok -- http://www.icann.org/epp#ok',
			    #$_ !~ m/WHOIS/ &&
			    $_ !~ m/For more information on Whois status codes/si &&
				$_ ne 'NOT FOUND' &&
				$_ !~ m/^No match for domain/si &&
				$_ !~ m/^WHOIS Server:/si &&
				$_ !~ m/^Creation Date:/si &&
				$_ !~ m/^Updated Date:/si &&
				$_ !~ m/^Registry Expiry Date:/si &&
				$_ !~ m/^Sponsoring Registrar/si &&
				$_ !~ m/^Name Server:/si &&
				$_ !~ m/^DNSSEC:/si &&
				$_ !~ m/^(?:Domain )?Status:/si
			} map { trim( $_ ); } split /\n+/ , $entry_text;
			foreach my $entry_text_line (@entry_text_lines) {
			    my $entry_text_line_clean = $entry_text_line;
			    $entry_text_line_clean =~ s/^[^:]+://si;
			    $entry_text_line_clean = StringNormalizer::_clean( $entry_text_line_clean );
			    # Note : the goal here is to avoid artificially boosting irrelevant entities that appear in multiple WHOIS server entries
			    # => at most one occurrence in the WHOIS records should be taken into account
			    # TODO: apply a better normalization method
			    if ( length( $entry_text_line_clean ) && ! $seen{ lc( $entry_text_line_clean ) }++ ) {
				# page-based filtering => for safety we only include elements that are match by the page content ?
				push @whois_data , $entry_text_line_clean;
			    }
			}
		    } @{ $arrayref };
		}
	    };
	    if ( $@ ) {
		$this->logger->warn( "An error occurred while requesting domain name information for : $host_name" );
	    }
	    shift @host_components;
	}

	# update
	$this->object->set_field( 'whois' , encode_json( \@whois_data ) , namespace => 'web' );

    }
    
    #return \@whois_data;
    return decode_json( $this->object->get_field( 'whois' , namespace => 'web' ) );

}

# TODO : turn WHOIS/Domain data into a separate Modality ?
# TODO : we should just override _segments_builder since we don't want to cache/serialize URLs
#override '_segments_builder' => sub {
sub data_generator {

    my $this = shift;

    my @data = ( $this->object->url );

    my $whois_data = $this->generate_whois_data;
    push @data , @{ $whois_data };

    return \@data;

    # TODO : also expand by collecting e.g. titles of all URLs derivable from this URL

};

# CURRENT : sort references by entities that are maximally identifiable
# SLOT => estimate slot confidence based on how good of a Freebase match we get ...

# CURRENT : the responsability of UrlModality should simply be to provide a list of its tokens ?
# Note : specific overload for UrlModality since we don't want to rely on a statistical segmentation of the underlying URL (?)
sub supports_token {

    my $this = shift;
    my $token = shift;

    # TODO : needs to be cleaned up => the modality should only be responsible for providing its set of tokens
    #        => ( maybe with a probability for each => fluent modalities would have 1 probabilities for most (if not all) of their tokens )
    my $result = undef;
    my $basic_support = $this->SUPER::supports_token( $token );
    if ( defined( $basic_support ) ) {
	$result = $basic_support;
    }
    elsif ( $this->content =~ ( ref( $token ) ? $token->as_regex : Web::Summarizer::Token->create_regex( $token , anywhere => 1 ) ) ) {
	$result = [ $token , 1 , [ $this->utterances->[ 0 ] ] ];
    }
    else {
	# TODO : all this should be encapsulated in a "support" class => Web::Summarizer::Support ?
	$result = [ $token , 0 , [] , [] ];
    }

    return $result;

}

# TODO : turn this into a default for non-fluent modalities (i.e. this also means creating a base class for - at least - fluent modalities) ?
sub _sequence_class_builder {
    return 'Web::Summarizer::StringSequence';
}

# still meaningful ?
=pod
sub _words_builder {

    my $this = shift;
    my $url_data = shift;

    # recipe to produce url words given url data
    # TODO : basically move builder code here

    # CURRENT : however, how do we add the ability to generate say n-grams on top of this ? ==> have to "combinable" with other basic processors ...

   return new Modality::Operator::StringSegmenter( segmenter => \&url_words_builder );

}
=cut

# old version
=pod
# TODO : add support for ngram generation
# TODO : discard current serialization files
# TODO : add support for serialization
sub url_words_builder {

    my $url_data = shift;

    # TODO : use all available modalities
    my $content = join( " " , @{ $url_data->get_modality_data( 'content' )->render } );

    my @url_words;
    
    # 1 - split URL according to / characters
    my @url_elements = grep { length($_); } split /\p{Punct}+/, $url_data->url;
	
    # 2 - generate dictionory for this URL (should it become a field of its own)
    # Note : tokenize content, removing any potential URL string (for now anything that contains a / character
    my %dictionary;
    map { $dictionary{ lc($_) }++; } grep { $_ !~ m#/# } split( /\s+/ , $content );

    # 3 - split URL segments using max match segmentation based on the set of identified nodes as well as individual tokens from the target content
    foreach my $url_element (@url_elements) {
	
	$url_element = lc($url_element);
	
	# check whether the element exist as is in our dictionary
	# (is there a cleaner way ? right to left verfication ?)
	if ( defined( $dictionary{ $url_element } ) ) {
	    push @url_words, $url_element;
	    next;
	}
	
	my @characters = split //, $url_element;
	my @buffer;
	my $has_match = 0;
	while ( scalar(@characters) ) {
	    
	    my $char = shift @characters;
	    my $string = lc( join("", @buffer, $char) );
	    
	    if ( ! defined( $dictionary{ $string } ) ) {
		
		if ( $has_match ) {
		    
		    push @url_words, join("", @buffer);
		    
		    # clear buffer
		    @buffer = ();
		    
		    # reset has match status
		    $has_match = 0;
		    
		}
		
	    }
	    else {
		$has_match = 1;
	    }
	    
	    push @buffer, $char;
	    
	}
	
	if ( scalar(@buffer) ) {
	    push @url_words, join("", @buffer);
	}
	
    }
    
    # TODO : return as an ArrayRef ?
    return join( " " , @url_words );

}
=cut

with ( 'Modality' => { fluent => 0 , namespace => 'web' , id => 'url' } );

__PACKAGE__->meta->make_immutable;

1;
