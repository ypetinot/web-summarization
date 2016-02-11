package ContextElement;

# abstracts the notion of a context element, that is a unit of context

# constructor
sub new {
    my $that = shift;
    my $element_text = shift;
    my $element_origin = shift; # origin URL
    my $element_target = shift; # target URL

    my $package = ref($that) || $that;

    my $hash = {
		_text => $element_text,
		_origin => $element_origin,
		_target => $element_target
		};

    bless $hash, $package;
}

# get text of this element
sub text {
    my $this = shift;
    return $this->{_text};
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
