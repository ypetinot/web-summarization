package WWW::String;

use strict;
use warnings;

use List::Util qw[min max];

# normalize string
sub normalize {

    my $string = shift;

    $string =~ s/\s+/ /g;
    $string =~ s/^ //;
    $string =~ s/ $//;
    $string =~ s/^[[:punct:]]+$//;

    if ( ! length($string) ) {
        return undef;
    }

    return $string;

}


# check that two string match, irrespective of punctuation, whitespaces, etc.
sub check_match {
    
    my $string = shift;
    my $reference = shift;

    my @references = (ref($reference) eq 'ARRAY')?@{$reference}:$reference;
    
    foreach my $reference (@references) {
	
	# print STDERR "checking match between {$string} and {$reference} ...\n";

	if ( $string eq $reference ) {
	    return $reference;
	}

	# lower case both string and reference
	my $string_lower = lc($string);
	my $reference_lower = lc($reference);
	
	# attempt to match without punctuation
	my $string_no_punctuation = $string_lower;
	$string_no_punctuation =~ s/[[:punct:]]/ /g;
	my $reference_no_punctuation = $reference_lower;
	$reference_no_punctuation =~ s/[[:punct:]]/ /g;
	if ( $string_no_punctuation eq $reference_no_punctuation ) {
	    return $reference;
	}
	
	# attempt to match without spaces
	my $string_no_space_no_punctuation = $string_no_punctuation;
	$string_no_space_no_punctuation =~ s/\s+//g;
	my $reference_no_space_no_punctuation = $reference_no_punctuation;
	$reference_no_space_no_punctuation =~ s/\s+//g;
	if ( $string_no_space_no_punctuation eq $reference_no_space_no_punctuation ) {
	    return $reference;
	}
		
    }
    
    return undef;
    
}

# word overlap between two strings
# two values are returned, using both strings as a reference
sub wordoverlap {

    my $string1 = shift;
    my $string2 = shift;

    my $split_regex = qr/(\s|[[:punct:]])+/i;

    my %tokens;

    my %tokens1 = map { $_ => 1 } split $split_regex, $string1;
    my %tokens2 = map { $_ => 1 } split $split_regex, $string2;

    map { $tokens{$_}++; } keys(%tokens1);
    map { $tokens{$_}++; } keys(%tokens2);

    my $n_tokens1 = scalar(keys(%tokens1));
    my $n_tokens2 = scalar(keys(%tokens2));

    if ( !$n_tokens1 || !$n_tokens2 ) {
	return (0, 0);
    }

    my $n_overlap = 0;
    foreach my $key (keys(%tokens)) {
	if ( defined($tokens1{$key}) && defined($tokens2{$key}) ) {
	    $n_overlap++;
	}
    }

    return ($n_overlap/$n_tokens1, $n_overlap/$n_tokens2);

}

# compute word overlap ratio between two strings
sub distance_wordoverlap {

    my $string1 = shift;
    my $string2 = shift;

    my ($wordoverlap1, $wordoverlap2) = wordoverlap($string1, $string2);

    return (1 - min($wordoverlap1, $wordoverlap2));

}

    
1;
