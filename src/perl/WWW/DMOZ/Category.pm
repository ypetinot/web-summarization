package WWW::DMOZ::Category;

sub new {
    
    my $that = shift;
    my $parent = shift;
    my $name = shift;

    my $class = ref($that) || $that;

    my $hash = {};

    $hash->{parent} = $parent;
    $hash->{name} = $name;
    $hash->{children} = [];

    bless $hash, $class;

    return $hash;

}

sub addSubCategory {

    my $this = shift;
    my $subcat = shift;

    push @{$this->{children}}, $subcat;

}

sub getSubCategories {

    my $this = shift;

    return @{$this->{children}};

}

1;
