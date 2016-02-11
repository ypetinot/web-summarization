package Web::Summarizer::TokenRanker::SimpleTokenRanker;

use strict;
use warnings;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::TokenRanker' );

sub filter {
    my $this = shift;
    return 1;
}

method weighter ( :$source , :$token , :$utterance , :$utterance_prior ) {
    return $utterance_prior;
}

__PACKAGE__->meta->make_immutable;

1;
