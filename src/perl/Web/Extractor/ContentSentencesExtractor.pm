package Web::Extractor::ContentSentencesExtractor;

use strict;
use warnings;

use HTMLRenderer::LynxRenderer;

use Text::Trim;

use Moose::Role;
#use namespace::autoclean;

# TODO : applied to summarizer ?
sub extract_sentences {

    my $this = shift;
    my $instance = shift;

    my $content = $instance->get_field( 'content' );
    my @raw_sentences;

    # generate "rendered" content
    my $rendered_content = "";
    if ( $content ) {
	my $rendered_content_raw = HTMLRenderer::LynxRenderer->render( $content );
	if ( $rendered_content_raw ) {
	    @raw_sentences = map { trim $_; } split /\n+|[[:cntrl:]]+/, $rendered_content_raw;
	}
    }

    # CURRENT : what happens if we force to use a regular sentence builder instead of (possibly) a WordGraph::SentenceBuilder ? ==> should be fine, the type of SentenceBuilder is prescribed by the data format used to represent the sentences
    #my @content_sentences = map { $this->sentence_builder->build( $_ , $instance ); } grep { length( $_ ) && $_ !~ m/^\p{Punct}+$/ } @raw_sentences;
    #my @content_sentences = map { $this->_extractor_sentence_builder->build( $_ , $instance ); } grep { length( $_ ) && $_ !~ m/^\p{Punct}+$/ } @raw_sentences;

    return \@raw_sentences;

}

with('Web::Extractor::SentenceExtractor');

#__PACKAGE__->meta->make_immutable;

1;
