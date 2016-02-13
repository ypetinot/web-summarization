package ContentDistribution::PlainTextAnalyzer;

use strict;
use warnings;

use ContentDistribution::TokenAnalyzer;
use Tokenizer;

sub content_distribution {

    my $raw_text = shift;
    my $mode = shift || undef; # not used for now

    my @tokens = @{ Tokenizer->tokenize($raw_text) };

    return \@tokens;
    
}

1;
