package Sentence;

sub new {

    my $this = shift;
    my $class = $this || ref($this);

    my $string = shift;

    my $hash = {};
    $hash->{_string} = $string;

    my $ref = bless $hash, $class;

    $ref->tokenize();

    return $ref;

}


sub tokenize {

    my $this = shift;
    $this->{_tokens} = [];

#    print ">> tokenizing : " . $this->{_string} . "\n";

=pod
    while ( $this->{_string} =~ m/(\w+)/g ) {
	my $token = $1;
	$token = lc($token);
	push @{$this->{_tokens}}, $token;
    }
=cut
    
    # todo: need to integrate a better tokenizer
    my $cleansed_string = $this->{_string};
    $cleansed_string =~ s/\.|\,|\?|\!/ /sgi;
    $cleansed_string =~ s/\'|\"/ /sgi;
    my @tokens = split /\s+/, $cleansed_string;
    @tokens = map { lc($_) } @tokens;

    $this->{_tokens} = \@tokens;

}

sub dump {
    my $this = shift;
    return join(" ", @{$this->{_tokens}});
}

sub numberOfTokens {
    my $this = shift;
    if ( defined($this->{_tokens}) ) {
	return scalar(@{$this->{_tokens}});
    }
    else {
	return 0;
    }
}

sub token {
    my $this = shift;
    my $index = shift;
    my $value = shift;

    if ( $value ) {
	$this->{_tokens}->[$index] = $value;
    }
    else {
	$value = $this->{_tokens}->[$index];
    }
    
    return $value;
}

sub text {
    my $this = shift;
    #return $this->{_string};
    return join(' ', @{$this->{_tokens}});
}

sub containsToken {
    my $this = shift;
    my $token = shift;

    foreach my $_token (@{$this->{_tokens}}) {
	if ( $token eq $_token ) {
	    return 1;
	}
    }

    return 0;
}

1;
