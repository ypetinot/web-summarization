package StringNormalizer;

use strict;
use warnings;

use Text::Trim;

our $leading_trailing_punctuation_set = qr/[\'\",;]+/;

sub _trim {

    my $string = shift;
    
    my $trimmed_string = $string;
    
    # remove redundant whitespaces
    $trimmed_string =~ s/\s+\s/ /sg;
    
    return trim( $trimmed_string );

} 

sub _clean {
    
    my $string = shift;

    my $cleaned_string = $string;

    # remove control characters (should this become a parameter ?)
    $cleaned_string =~ s/[[:cntrl:]]//sg;

    # remove non-printable characters
    $cleaned_string =~ s/\P{PosixPrint}+//sg;

    return _trim( $cleaned_string );

}

# normalize a string
sub _normalize {

    my $string = shift;

    my $normalized_string = $string;
    $normalized_string = lc($normalized_string);

    # remove leading/trailing punctuation if it is in the target set
    $normalized_string =~ s/^${leading_trailing_punctuation_set}//g;
    $normalized_string =~ s/${leading_trailing_punctuation_set}$//g;
    
    return _trim( $normalized_string );

}

# plural normalize a string
sub _plural_normalize {

    my $string = shift;

    my $normalized_string = _normalize($string);
    #$normalized_string =~ s/(?!:s)s$//;
    #$normalized_string = ( stem($normalized_string) )->[0];

    return $normalized_string;

}

# TODO : optimization ? => cache regexes ?
sub normalize_punctuation {

    my $string = shift;
    
    my $normalized_string = $string;

    # normalize single quotes
    # TODO : need to do this via a mapping table
    while ( $normalized_string =~ s/\x{2019}/'/sg ) {};

    return $normalized_string;

}

1;
