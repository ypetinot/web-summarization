package DMOZ::Mapper;

# base class for all map/recursion operations

# constructor
sub new {

    my $that = shift;
    my %params = @_;

    my $class = ref($that) || $that;

    # object ref
    my $hash = {};
    foreach my $param (keys %params) {
	$hash->{$param} = $params{$param};
    }

    bless $hash, $class;

    return $hash;

}

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    # nothing

}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;

    # nothing

}

1;

