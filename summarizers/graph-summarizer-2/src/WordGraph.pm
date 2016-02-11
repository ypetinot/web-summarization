package WordGraph;

use strict;
use warnings;

# simple normalization function
sub _normalized {

    my $string = shift;

    my $normalized_string = lc( $string );
    return $normalized_string;

}

1;
