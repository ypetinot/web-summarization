package Web::Document::HtmlDocument;

use strict;
use warnings;

use Service::Web::Analyzer;
use StringNormalizer;

use Function::Parameters qw/:strict/;
use HTML::TreeBuilder 5 -weak; # Ensure weak references in use
use Text::Trim;

use Moose;
use namespace::autoclean;

with( 'Web::Document' );

sub _render {
    
    my $this = shift;
    # TODO : remove redundancy with html-renderer

    # TODO : move log message to parent class
    # TODO : create parent class (instead of using a role) ?
    $this->logger->info( "Rendering content for: " . $this->url );

    # TODO : rely on tika service ?
    # Note / TODO : if we rely on tika across the board (i.e. for all content types) then the rendering method can probably be promoted to Web::Document
    # TODO : how can we avoid rerunning the analyzer to get multiple fields ?
    my $raw_data = $this->raw_data;
    
    # Note : clean up raw data
    $raw_data =~ s#<script(?:(?!</script>).)*</script>##sgi;

    my $data = defined( $raw_data ) ? Service::Web::Analyzer->content( $raw_data ) : undef;

    # normalize individual strings
    # TODO / Note : would a more wholistic normalization approach be necessary, e.g. a la http://www.perlmonks.org/bare/?node_id=532669 ?
    my @normalized_data = map { $this->normalize( $_ ); } @{ $data };

    return \@normalized_data;

}

sub normalize {

    my $this = shift;
    my $original_string = shift;

    my $normalized_string = $original_string;
    $normalized_string = StringNormalizer::normalize_punctuation( $normalized_string );
    
    return $normalized_string;

}  

# CURRENT : can we require the existence of this method with consuming a role ?
sub segment {

    my $this = shift;
    my $segmenter = shift;

    my $content_rendered = $this->render;

    # sentence segmentation
    my @content_segmented;
    foreach my $scu (@{ $content_rendered }) {
	
	if ( !length( $scu ) || $scu !~ m/[[:graph:]]$/ ) {
	    next;
	}

	# Refining segmentation
	# TODO : should this be promoted to a parent class ?
	# Note : \P{PosixGraph}+ would probably be acceptable as well
	my @scu_sentences = grep { length( $_ ) } split /(?:(?<=\w[\.\!\?])\s+(?=[A-Z]))|(?:\P{PosixPrint}+)/ , trim( $scu );

	push @content_segmented , @scu_sentences;

    }

    return \@content_segmented;

}

around raw_data => sub {
    
    my $sub = shift;
    my $ret = $sub->( @_ );

    # Here we filter out anything that appears before the opening HTML tag => this is probably all that is needed to get Tika to work properly on a case like this:
    # <?php
    #      ob_start( 'ob_gzhandler' );
    # ?>
    # <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
    # <html>

    my $filtered_content = $ret;
    $filtered_content =~ s/^.*(?=\<(?:html|\!doctype))//sio;

    return $filtered_content;

};

has 'dom_tree' => ( is => 'ro' , isa => 'HTML::Element' , init_arg => undef , lazy => 1 , builder => '_dom_tree_builder' );
sub _dom_tree_builder {
    my $this = shift;
    return HTML::TreeBuilder->new_from_content( $this->raw_data );
}

# url comparison
sub _url_match {

    my $this = shift;
    my $url_obj_1 = shift;
    my $url_obj_2 = shift;    

    # TODO : call Service::Web::UrlNormalizer
    my $url_obj_2_normalized = $url_obj_2->canonical;

    return ( $url_obj_1->eq( $url_obj_2 ) ) || ( $url_obj_1->eq( $url_obj_2_normalized ) ) || 0 ;

}

method get_links( :$target = undef ) {

    # TODO : enable links method via delegation => cleaner interface
    my $links = $self->dom_tree->extract_links( 'a' );

    my @links_entries;
    foreach my $link (@{ $links }) {

	my($link_url_relative, $element, $attr, $tag) = @$link;

	# generate absolute url
	my $absolute_url = URI->new_abs( $link_url_relative , $self->url );

	if ( defined( $target ) && ( ! $self->_url_match( $target , $absolute_url ) ) ) {
	    $self->logger->trace( "Skipping irrelevant linking URL : $absolute_url / $target" );
	    next;
	}

	push @links_entries , [ $absolute_url , $link_url_relative , $element, $attr , $tag ];

    }

    return \@links_entries;

}

# TODO : can be do better semantically ? => seems ok for now
with( 'Text::Segmentable' );

__PACKAGE__->meta->make_immutable;

1;
