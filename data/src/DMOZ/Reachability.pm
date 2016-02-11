package DMOZ::Reachability;

use strict;
use warnings;

use List::Util qw/min/;

sub summary_length {

    my $this = shift;
    my $summary_string = shift;
    
    my $summary_length = scalar( split /(?:\s|\p{Punct})+/ , $summary_string );

    return $summary_length;

}

sub parent_category {

    my $that = shift;
    my $category = shift;
    my $depth = shift || 1 ;

    my @category_components = split /\// , $category;
    my $parent_category = join( '/' , map { $category_components[ $_ ] } ( 0 .. min( $depth , $#category_components ) ) );

    return $parent_category;

}

1;
