package Web::Summarizer::State;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# stats
has 'stats' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

__PACKAGE__->meta->make_immutable;

1;
