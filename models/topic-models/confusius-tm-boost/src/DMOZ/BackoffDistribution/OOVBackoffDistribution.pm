package DMOZ::BackoffDistribution::OOVBackoffDistribution;

# Maps unassigned vocabulary to OOV (merged with the original OOV symbol)
# Effectively this is implemented by assigning probability 1 to all unassigned vocabulary as well as the OOV symbol

use strict;
use warnings;

use DMOZ::BackoffDistribution;
use base qw(DMOZ::BackoffDistribution);

# compute method
sub compute {

    my $this = shift;

    my @vocabulary_words = @{ $this->{_vocabulary}->word_indices() };
    foreach my $vocabulary_word (@vocabulary_words) {
	
	if ( $this->assigned($vocabulary_word) ) {
	    next;
	}

	$this->{_distribution}->probability($vocabulary_word,1);

    }

}

1;

