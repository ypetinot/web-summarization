package Web::Summarizer::UrlStringSequenceBuilder;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::StringSequenceBuilder' );

# TODO : add support for serialization
# TODO : discard current serialization files
has 'url_words' => ( is => 'ro' , isa => 'Web::Summarizer::Sequence' , init_arg => undef , lazy => 1 , builder => '_url_words_builder' );
sub _url_words_builder {

    my $this = shift;

    # TODO : use all available modalities
    my $content = $this->object->get_field( 'content.rendered' );

    my @url_words;
    
    # 1 - split URL according to / characters
    my @url_elements = grep { length($_); } split /\p{Punct}+/, $this->object->url;
	
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
    
    return new Web::Summarizer::StringSequence( object => $this->object , source_id => 'url_words' , object_sequence => \@url_words );
    
}

__PACKAGE__->meta->make_immutable;

1;
