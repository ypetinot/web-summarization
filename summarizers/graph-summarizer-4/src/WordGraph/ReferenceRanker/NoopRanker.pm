package WordGraph::ReferenceRanker::NoopRanker;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker' );

sub _run {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentences = shift;
    my $full_serialization_path = shift;

    my @output = map { [ $_ , 0 ] } @{ $reference_sentences };

    return \@output;

}

__PACKAGE__->meta->make_immutable;

1;
