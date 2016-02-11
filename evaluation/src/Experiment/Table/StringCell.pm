package Experiment::Table::StringCell;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Experiment::Table::Cell' );

has 'value' => ( is => 'ro' , isa => 'Str' , required => 1 );

__PACKAGE__->meta->make_immutable;

1;
