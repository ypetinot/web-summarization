package Experiment::Table::HeaderCell;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Experiment::Table::StringCell' );

sub value {
    my $this = shift;
    return _make_bf( $this->SUPER::value );
}

sub _make_bf {
    my $string = shift;
    return '\textbf{' . $string . '}';
}

__PACKAGE__->meta->make_immutable;

1;
