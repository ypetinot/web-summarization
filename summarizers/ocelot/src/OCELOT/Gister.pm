package OCELOT::Gister;

# base class for the 3 OCELOT gisters

use strict;
use warnings;

use DMOZ::Hierarchy;

# constructor
sub new {

    my $that = shift;

    my $class = ref($that) || $that;

    my $ref = {};

    # build length distribution
    # TODO
    # $ref->{_length_distribution} = DMOZ::Hierarchy::get('length_distribution');

    bless $ref, $class;

    return $ref;

}

# gist probability
sub probability {

    return 0;

}

# gist perplexity (needed ?)
sub perplexity {

    return 0;

}

# access to gist length distribution
sub getLengthDistribution {

    my $this = shift;

    return $this->{_length_distribution};

}

1;
