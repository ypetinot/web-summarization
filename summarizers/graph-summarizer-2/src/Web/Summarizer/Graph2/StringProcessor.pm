package Web::Summarizer::Graph2::StringProcessor;

use Moose;

use Text::Trim;

sub cleanse {

    my $that = shift;
    my $string = shift;

    $string =~ s/^\p{Punct}+//;
    $string =~ s/\p{Punct}+$//;

    return trim($string);

}

no Moose;

1;
