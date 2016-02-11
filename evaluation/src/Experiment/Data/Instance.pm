package Experiment::Data::Instance;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# id
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 );

__PACKAGE__->meta->make_immutable;

1;
