package Web::Summarizer::SentenceBuilder;

# Note : should only be used to build sequences from raw strings that are known to be natural language sentences

use strict;
use warnings;

use Environment;
use Web::Summarizer::Sentence;
# TODO : make this a Web::Summarizer::Sentence::Token / Web::Summarizer::SentenceToken instead ?
use Web::Summarizer::Token;

use Clone qw/clone/;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::StringSequenceBuilder' );

# sequence class
has '+_sequence_class' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'Web::Summarizer::Sentence' );

# do chunking
has 'do_chunking' => ( is => 'ro' , isa => 'Bool' , default => 1 );

__PACKAGE__->meta->make_immutable;

1;
