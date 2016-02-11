package TitleTargetAdapter;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# Note : could segment title based on summary segmentation, or vice-verca ? Or look for overlapping sequences and segment accordingly, other use chunker's output
# 1 - ==> self-align title with summary
# this should even allow us to align unknown acronyms
# 2 - ==> segment summary/title according to alignment, i.e. get phrases
# 3 - ==> align segmented summary with target title
# 4 - ==> decode

# open problem :
# if we pair up sentences automatically, we can train a translation model. Problem, how do we pair up sentences ? minimum word overlap ?
# 1 - focus on words that are in the reference summary and that I want to align replace
# 2 - start by aligning only sequences that share at least a word (two words ?)
# 3 - as I align and gain confidence in alignment, set alignments, e.g. a-la-SNOWBALL => if so there is no need to do the confusion network approach


# Note : character-based alignment to handle acronyms, spelling variations, etc.
sub align_title_summary {

    my $this = shift;
    my $title = shift;
    my $summary = shift;

    # CURRENT : what kind of alignment are we looking for ? permutations must be possible, also word/phrase based, but allow some character level matching/skipping
    

}

__PACKAGE__->meta->make_immutable;

1;
