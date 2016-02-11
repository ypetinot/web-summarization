package AlignmentAdapter;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

sub alignment_distribution {

    my $this = shift;
    my $target = shift;
    my $reference = shift;
    my $reference_term = shift;

    my @alignment_distribution;

    # CURRENT : make sure alignment pipeline is in place

    # 1 - retrieve reference utterances that contain the term to replace
    my $reference_utterances = $reference->utterances( $reference_term );
    
    # 2 - for each reference utterance, retrieve target utterances that contain at least one term contained in the reference utterance
    foreach my $reference_utterance (@{ $reference_utterances }) {
	
	my $reference_utterance_terms = $this->reference_utterances_terms( $reference_utterance );

	foreach my $reference_utterance_term ( @{ $reference_utterance_terms } ) {

	    my $target_utterances = $target->utterances( $reference_utterance_term );

	    foreach my $target_utterance ( @{ $target_utterance } ) {
		
		# 3 - align reference and target utterances
		
		# 4 - update conditional (reference-target) alignment distribution

	    }

	}

    }

    # TODO : this distribution might just be the reason why fusion is needed in the end since we can ultimately get more confidence into a particular target alignment value ?
    return \%alignment_distribution;

}

__PACKAGE__->meta->make_immutable;

1;
