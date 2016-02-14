package DMOZ::BackoffDistribution::MissingVocabularyRenormalizedBackoffDistribution;

# Generates distribution over Unassigned (missing) vocabulary
# The distribution is renormalized based on corpus frequency statistics

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

	$this->{_distribution}->probability($vocabulary_word,$this->{_vocabulary}->get_tf($vocabulary_word));

    }

    # renormalize distribution
    $this->{_distribution}->normalize();

}

1;

