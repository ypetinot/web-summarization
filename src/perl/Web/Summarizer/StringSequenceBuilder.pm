package Web::Summarizer::StringSequenceBuilder;

use strict;
use warnings;

use Web::Summarizer::StringSequence;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::SequenceBuilder' );

# sequence class
has '_sequence_class' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'Web::Summarizer::StringSequence' );

__PACKAGE__->meta->make_immutable;

1;
