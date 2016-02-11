package DMOZ::TemplateAnalysis;

use strict;
use warnings;

use Carp::Assert;
use File::Slurp;
use List::MoreUtils qw/uniq/;

sub _list_all_categories {

    my $summary_file = shift;

    my $base_file = $summary_file;
    $base_file =~ s/\.summary$//sgi;

    affirm { -f $base_file } "Base file must exist: $summary_file / $base_file" if DEBUG;

    my @_temp = uniq map { my @fields = split /\t/ , $_; $fields[ 1 ] } read_file( $base_file , chomp => 1 );
    affirm { scalar( @_temp ) } "Full category information must be available" if DEBUG;
    
    my $full_category = $_temp[ 0 ];
    my @full_category_components = split /\// , $full_category;

    my $summary_level = scalar( @full_category_components );

    my @categories;
    while ( scalar( @full_category_components ) ) {
	push @categories , [ join( "/" , @full_category_components ) , scalar( @full_category_components ) ];
	pop @full_category_components;
    }

    # Note : the first category listed is the full category, which has already been processed
    ###shift @categories;

    return ( $summary_level , \@categories );

}

1;
