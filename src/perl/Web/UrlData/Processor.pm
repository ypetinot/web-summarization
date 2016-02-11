package Web::UrlData::Processor;

# TODO : find a better name for this role => this is not fundamentally about alignment, but more about the type of modalities you use => Moda

use strict;
use warnings;

use Moose::Role;

has 'alignment_sources' => ( is => 'ro' , isa => 'ArrayRef[Str]' , builder => '_alignment_sources_builder' );
sub _alignment_sources_builder {
    my $this = shift;
    my @default_sources = ( 'title' , 'url' , 'content' );
    return \@default_sources;
}

1;
