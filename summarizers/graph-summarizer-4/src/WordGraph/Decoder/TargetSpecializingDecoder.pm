package WordGraph::Decoder::TargetSpecializingDecoder;

# TODO : to be removed

use Moose;
use namespace::autoclean;

# ngram order for backoff lm's
has 'ngram_order' => ( is => 'ro' , isa => 'Num' , required => 1 );

# find optimal path for the current set of weights
sub _decode {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;

    # 1 - generate (backoff) LM for $instance
    my $backoff_lm = $instance->get_lm( 'backoff' , $this->ngram_order );

    # 2 - backward/forward (Viterbi ?)
    

__PACKAGE__->meta->make_immutable;

1;
