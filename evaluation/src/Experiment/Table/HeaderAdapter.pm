package Experiment::Table::HeaderAdapter;

use strict;
use warnings;

sub adapt {

    my $that = shift;
    my $header = shift;

    my $header_adapted = $header;
    
    # 1 - we skip "oracle-category" systems
    if ( $header_adapted =~ m/oracle-category/ ) {
	return undef;
    }
    
    # remove "-extractive-"
    $header_adapted =~ s/\-extractive\-/-/sgi;
    
    # remove "graph4-adaptation-"
    $header_adapted =~ s/graph4\-adaptation\-//sgi;
    
    # remove "adaptation-"
    $header_adapted =~ s/adaptation\-//sgi;
    
    # replace "^adaptation:::" with "regular:::"
    $header_adapted =~ s/^adaptation:::/regular:::/sgi;

    # shorten "concatenation" to "concat"
    $header_adapted =~ s/concatenation/concat/sgi;

    # shorten "replacement" to "replace"
    $header_adapted =~ s/replacement/replace/sgi;

    # shorten "compression" to "compress"
    $header_adapted =~ s/compression/compress/sgi;

    # replace "^dmoz$" with "odp"
    $header_adapted =~ s/^dmoz$/odp/sgi;

    # replace "^adapt-hungarian$" with "adapt-hungarian@compress"
    $header_adapted =~ s/:::adapt-hungarian(?=[^@])/:::adapt-hungarian\@compress/sgi;

    return $header_adapted;

}

1;
