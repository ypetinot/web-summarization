package Modality::SingleStringSequenceModality;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Modality::ModalityBase' );

sub utterance {
    my $this = shift;
    my $utterances = $this->utterances;
    return scalar( @{ $utterances } ) ? $utterances->[ 0 ] : undef;
}

__PACKAGE__->meta->make_immutable;

1;
