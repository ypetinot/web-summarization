package TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::EosMarkerSegment;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::MarkerSegment' );

sub _position_builder {
    my $this = shift;
    return ( $this->parent->to + 1 )
}

sub _marker_string_builder {
    return '</s>';
}

__PACKAGE__->meta->make_immutable;

1;
