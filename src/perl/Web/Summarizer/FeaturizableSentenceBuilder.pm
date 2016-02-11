package Web::Summarizer::FeaturizableSentenceBuilder;

# Note : not used as it does not in improving code abstraction (a Featurizer instance is needed in all cases)

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::SentenceBuilder' );

has 'featurizer' => ( is => 'ro' , does => 'Featurizer' , required => 1 );

with( 'Featurizable' );

__PACKAGE__->meta->make_immutable;

1;
