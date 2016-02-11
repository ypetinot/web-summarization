package GistTokenizer;

use strict;
use warnings;

#use Moose;
use Text::Trim;

sub tokenize {

    my $string = shift;
    my @tokens;

    # my @tokens = grep { length( $_ ); } split / |\p{Punct}/, $string;

    @tokens = map { trim($_); } split /(\W)/, $string;
    @tokens = grep { length( $_ ); } @tokens;

    return \@tokens;

}

#no Moose;

1;
