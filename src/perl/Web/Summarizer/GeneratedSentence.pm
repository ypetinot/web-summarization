package Web::Summarizer::GeneratedSentence;

use strict;
use warnings;

use Moose;

extends( 'Web::Summarizer::Sentence' );

# score
has 'score' => ( is => 'ro' , isa => 'Num' , required => 1 );

# override: token transformer
# Note : the full processing carried out in Sentence is not necessary here (we don't need to have well segmented named entities)
# TODO : what is the impact on performance metrics ?
sub token_transformer {

    my $this = shift;
    my $token_sequence = shift;
    my $component_id = shift;

    return $this->Web::Summarizer::StringSequence::token_transformer( $token_sequence );

}

1;
