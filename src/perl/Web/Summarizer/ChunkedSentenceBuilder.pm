# TODO : to be removed
package Web::Summarizer::ChunkedSentenceBuilder2;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::SentenceBuilder' );

# for do_chunking to false
has '+do_chunking' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , default => 0 );

__PACKAGE__->meta->make_immutable;

1;
