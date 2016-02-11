package GistGraph::Node::Extractor;

# Base class for all (Node) Extractors

use strict;
use warnings;

use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

# fields
has 'id' => (is => 'ro', isa => 'Str', required => 1);
has 'url_data' => (is => 'ro', isa => 'ArrayRef[Category::UrlData]', required => 0, traits => [ 'DoNotSerialize' ]);
has 'targets' => (is => 'ro', isa => 'ArrayRef[Str]', required => 0, traits => [ 'DoNotSerialize' ]);

# constructor
sub BUILD {

    my $this = shift;
    my $args = shift;

}

# extraction method
sub extract {

    my $this = shift;

    # TODO: create class to conveniently have all the data for one URL encapsulated in a single object ?  
    my $raw_data = shift;
    my $target_id = shift;

    return undef;

}

no Moose;

1;
