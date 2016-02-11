package Web::Summarizer::FeaturizedToken;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::Token' );

# features
has 'features' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

__PACKAGE__->meta->make_immutable;

1;
