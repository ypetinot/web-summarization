package WWW::Summarization::Context::ContextElement;

# abstracts the notion of a context element, that is a unit of context

# constructor
sub new {

    my $that = shift;
    my $data = shift;
    
    my $package = ref($that) || $that;

    my $hash = {
	_data => $data,
    };
    
    bless $hash, $package;

}

# context facets
sub facets {
    my $this = shift;
    return grep { !m/^\-/ } keys(%{$this->{_data}});
}

# get/set text of this element
sub text {
    my $this = shift;
    my $facet = shift;
    my $string = shift;

    if ( ! defined($string) ) {
	return $this->{_data}->{$facet};
    }
    else {
	$this->{_data}->{$facet} = $string;
    }
}

# does the element match the specified string
sub matches {

    my $this = shift;
    my $string = shift || '';
   
    my $lc_this = lc($this->{_text});
    my $lc_string = lc($string);

    if ( $lc_this =~ m/$lc_string/ ) {
	return 1;
    }
    
    return 0;

}

1;
