package TargetAdapter::LocalMapping::SimpleTargetAdapter::NoopSlot;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot' );

# Note : type filtering takes place at candidate generation-time
sub _filler_candidates_builder {

    my $this = shift;

    # No candidates, we let the slot provide the default filler
    my %filler_candidates;

    return \%filler_candidates;

}

# Note : is this ok ? if so, is the filler_candidates_builder method even necessary ?
sub _current_filler_prior_builder {
    my $this = shift;
    return 1;
}

sub _allow_compression_builder {
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;
