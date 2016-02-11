package NGrams;

# function to generate n_grams
sub generate_n_grams {

    my $order = shift;
    my $token_stream = shift;
    my $id = shift || "unknown";

    my %ngrams;

    if ( ! defined( $token_stream ) ) {
	print STDERR "[NGrams] invalid token stream for: $id / $order ...\n";
    }
    else {

	my $placeholder = "[[NULL]]";
	my @window;
	
	# init window
	for (my $i=0; $i<$order; $i++) {
	    push @window, $placeholder;
	}

	my $n_tokens = scalar(@{ $token_stream });
	for (my $i=0; $i<($n_tokens + $order - 1); $i++) {

	    my $symbol = undef;	    
	    if ( $i >= $n_tokens ) {
		$symbol = $placeholder;
	    }
	    else {
		$symbol = $token_stream->[$i];
	    }
	    push @window, $symbol;
	    
	    while ( scalar(@window) > $order ) {
		shift @window;
	    }
	    
	    my $ngram = join(" ", @window);
	    $ngrams{$ngram}++;
	    
	}
	
    }

    return \%ngrams;

}

1;
