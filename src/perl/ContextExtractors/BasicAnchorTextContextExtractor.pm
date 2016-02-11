package ContextExtractors::BasicAnchorTextContextExtractor;

#use base ("ContextExtractor");
use Carp;
use WWW::Mechanize;
use HTML::LinkExtor;
use URI;

# base class for all context extractors
# given a target URL and a source URL, returns a string representing the context of the target contributed by the source

# no constructor, static objects only

sub id {
    my $that = shift;
    return 'context-basic-anchortext';
}

# summarize a URL
sub extract {
    my $that = shift;
    my $target_url = shift;
    my $source_url = shift;
    
    my @anchor_text_elements = map { chomp; my @data = split /\t/, $_; $data[1] } `get-context-anchortext '$target_url' '$source_url'`;

    return \@anchor_text_elements;
}

1;
