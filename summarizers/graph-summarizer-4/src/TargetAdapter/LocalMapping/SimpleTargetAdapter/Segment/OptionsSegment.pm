package TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::OptionsSegment;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment' );
with( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Span' );

# segment type
has 'type' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_type_builder' );
sub _type_builder {
    my $this = shift;
    return $this->parent->_status->[ $this->from ];
}

# TODO : is this even necessary ?
sub token_ids {
    my $this = shift;
    return $this->_range_sequence;
}

sub _tokens_builder {
    my $this = shift;
    my @tokens = map { $this->parent->original_sequence->object_sequence->[ $_ ] } @{ $this->token_ids };
    return \@tokens;
}

__PACKAGE__->meta->make_immutable;

1;
