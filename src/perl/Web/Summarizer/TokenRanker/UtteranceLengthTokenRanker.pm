package Web::Summarizer::TokenRanker::UtteranceLengthTokenRanker;

use strict;
use warnings;

# TODO : how can we avoid having to specify this everytime ?
use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::TokenRanker' );
with( 'Web::UrlData::Processor' );

sub filter {
    my $this = shift;
    my $token = shift;
    return 1;
}

method weighter ( :$source , :$token , :$utterance , :$utterance_prior ) {
    # Note : the length of the token is acting as a boosting factor since intuitively a longer token that occurs in many short utterances should be given potentially more semantic importance than a shorter token that occurs in an other exactly similar context
    return $utterance_prior * ( length( $token ) / $utterance->length );
}

__PACKAGE__->meta->make_immutable;

1;
