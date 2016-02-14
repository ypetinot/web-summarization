package DMOZ::WordAssigner;

# encapsulates the logic for various word assignment strategies

use strict;
use warnings;

# slows down the who thing ... not sure why ...
# use bigint;

use List::Util qw/max min sum/;
use Statistics::Distributions;

sub new {

    my $that = shift;
    my $total_documents = shift;
    my $children_document_counts = shift;

    my $class = ref($that) || $that;

    my $ref = {};
    $ref->{'total_documents'} = $total_documents;
    $ref->{'children_document_counts'} = $children_document_counts;
    $ref->{'_word_stats'} = {};

    bless $ref, $class;

    return $ref;

}

sub set_word_stats {

    my $this = shift;
    my $word = shift;
    my $word_stats = shift;

    $this->{'_word_stats'}->{$word} = $word_stats;

}

sub select {

    # can we have parameters ?
    my $this = shift;
    my $mode = shift;

    if ( $mode eq 'perplexity' ) {
	my ($p_c, $p_c_cond_w) = $this->compute_distributions();
	return $this->select_perplexity($p_c, $p_c_cond_w);
    }
    elsif ( $mode eq 'cross-entropy' ) {
	my ($p_c, $p_c_cond_w) = $this->compute_distributions();
	return $this->select_cross_entropy($p_c, $p_c_cond_w);
    }
    elsif ( $mode eq 'chi-square' ) {
	return $this->select_chi_square();
    }

    die "Unsupported assignment mode: $mode";

}

sub compute_distributions {

    my $this = shift;

    # p(w)
    my %p_w;
    
    # p(w,c)
    my %p_w_c;

    # p(w|c)

    # p(c)
    my %p_c;

    # p(c,w)
    my %p_c_w;

    # p(c|w)
    my %p_c_cond_w;

    my $total_documents = $this->{'total_documents'};
    my $n_children = scalar(@{$this->{'children_document_counts'}});

    # probability distribution for a given category [VALID - sums to 1]
    for (my $i=0; $i<$n_children; $i++) {
	$p_c{$i} = $this->{'children_document_counts'}->[$i] / $total_documents;
    }

    foreach my $word ( keys(%{ $this->{_word_stats} }) ) {
	
	# if ( $child_occurrences > 0 ) {
	#    $word2uniqueChildrenCount{$word}++;
	# }
	
	my $word_stats = $this->{'_word_stats'}->{$word};
	my $total_occurrences = $word_stats->{'total_occurrences'};

	# probability distribution for a given word (appears / does not appear) [VALID - sums to 1]
	$p_w{$word} = {};
	$p_w{$word}->{1} = $total_occurrences / $total_documents;
	$p_w{$word}->{0} = 1 - $p_w{$word}->{1};
	
	# category distribution knowing that a word appears
	$p_c_cond_w{$word} = {};

	# probability distribution for a given word wrt to the child categories
#	$p_w_c{$word} = {};
	for (my $i=0; $i<$n_children; $i++) {

	    my $child_occurrences = $word_stats->{'child_occurrences'}->[$i];
	    my $child_documents = $this->{'children_document_counts'}->[$i];
	    
#	    $p_w_c{$word}->{$i} = $child_occurrences / $total_documents;
#	    $p_w_c{$word}->{"-" . $i} = ( $child_documents - $child_occurrences ) / $total_documents;
 
	    $p_c_cond_w{$word}->{$i} = $child_occurrences / $total_occurrences;

	}

	# update p(c|w)
	# if ( !defined($p_c_w{$word}) ) {
	#    $p_c_w{$word} = {};
	# }

    }

    return (\%p_c, \%p_c_cond_w);

}

sub select_perplexity {

    my $this = shift;
    my $_p_c = shift;
    my $_p_c_cond_w = shift;

    my %p_c = %$_p_c;
    my %p_c_cond_w = %$_p_c_cond_w;

    my %entropy_p_c_cond_w;
    my %information_gain;

    #my %candidate_words;
    my %selected2score;
    # my %word2uniqueChildrenCount;
    
    # we cannot assign words that are proportionally too rare
    # if ( $total_occurrences / $total_documents < 0.1 ) {
    #if ( $n_relevant_children < $n_children ) { 
    #   next;
    #}
    # $candidate_words{$word}++;
    # my $n_relevant_children = 0;

    # if ( $child_occurrences && $child_documents ) {
    #	$n_relevant_children++;
    # }

    # first pass
    my $entropy_p_c = entropy(\%p_c);
    foreach my $word ( keys( %{ $this->{_word_stats} } ) ) {
	$entropy_p_c_cond_w{$word} = entropy($p_c_cond_w{$word});
	$information_gain{$word} = $entropy_p_c - $entropy_p_c_cond_w{$word};
    }

    # compute global stats
    print STDERR "[WordAssignment] original entropy: $entropy_p_c\n";

    my ($mean_entropy_p_c_cond_w, $stddev_entropy_p_c_cond_w) = mean_and_stddev(\%entropy_p_c_cond_w);
    print STDERR "[WordAssignment] mean a-posteriori entropy: $mean_entropy_p_c_cond_w\n";
    print STDERR "[WordAssignment] stddev a-posteriori entropy: $stddev_entropy_p_c_cond_w\n";

    my ($mean_information_gain, $stddev_information_gain) = mean_and_stddev(\%information_gain);
    print STDERR "[WordAssignment] mean information gain: $mean_information_gain\n";
    print STDERR "[WordAssignment] stddev information gain: $stddev_information_gain\n";

    # foreach my $word (keys(%information_gain)) {
    # 	print join("\t", $word, $entropy_p_w_c{$word}) . "\n";
    # }
    
    # second pass
    foreach my $word ( keys( %{ $this->{_word_stats} } ) ) {
    #foreach my $word ( keys(%candidate_words) ) {
	
	# we expect to allocate a small number of words at every step of the process
	# this implies that the majority of tokens have a low entropy relative to the
	# tokens to be assigned and that this 

	# information gain for this word
	#my $information_gain_word = $entropy_p_c - $entropy_p_c_w{$word};
	#$word2ig{$word} = $information_gain_word;
        
	# we're looking for words with 0 or negative information gain
	if ( $entropy_p_c_cond_w{$word} > $mean_entropy_p_c_cond_w + 3 * $stddev_entropy_p_c_cond_w ) {
#	if ( $information_gain{$word} > $mean_information_gain + 2 * $stddev_information_gain ) {
	    $selected2score{$word} = $entropy_p_c_cond_w{$word};
#	    $selected2score{$word} = $information_gain{$word};
	}

	# if ( $information_gain{$word} <= $mean_information_gain ) {
	#    $selected2score{$word} = $information_gain{$word};
	# }

    }

    return \%selected2score;

}

# decision for a single word based on cross-entropy
sub select_cross_entropy {

    my $this = shift;
    my $_p_c = shift;
    my $_p_c_cond_w = shift;

    my %p_c = %$_p_c;
    my %p_c_cond_w = %$_p_c_cond_w;

    my %cross_entropy;
    my %selected2score;

    # first pass
    foreach my $word ( keys( %{ $this->{_word_stats} } ) ) {
	$cross_entropy{$word} = cross_entropy(\%p_c, $p_c_cond_w{$word});
    }

    # compute global stats
    my ($mean_cross_entropy, $stddev_cross_entropy) = mean_and_stddev(\%cross_entropy);
    print STDERR "[WordAssignment] mean a-posteriori cross-entropy: $mean_cross_entropy\n";
    print STDERR "[WordAssignment] stddev a-posteriori cross-entropy: $stddev_cross_entropy\n";
    
    # second pass
    foreach my $word ( keys( %{ $this->{_word_stats} } ) ) {
    #foreach my $word ( keys(%candidate_words) ) {
	        
	# we're looking for words with a very high cross-entropy
	if ( $cross_entropy{$word} < $mean_cross_entropy - 2 * $stddev_cross_entropy ) {
	    $selected2score{$word} = $cross_entropy{$word};
	}

    }

    return \%selected2score;

}

# decision for a single word based on perplexity
sub select_chi_square {

    my $this = shift;

    # my $ntc_00 = ($total_documents - $child_documents) - ($total_occurrences - $child_occurrences);
    # my $ntc_10 = $total_occurrences - $child_occurrences;
    # my $ntc_01 = $child_documents - $child_occurrences;
    # my $ntc_11 = $child_occurrences;

    my %selected2score;

    my $total_documents = $this->{'total_documents'};
    my $n_children = scalar(@{$this->{'children_document_counts'}});

    my $degrees_of_freedom = $n_children - 1;

    my $chi_square_threshold = Statistics::Distributions::chisqrdistr ($degrees_of_freedom,.45);

    foreach my $word ( keys(%{ $this->{_word_stats} }) ) {

	my $word_stats = $this->{'_word_stats'}->{$word};
	my $total_occurrences = $word_stats->{'total_occurrences'};

	my @observed = ( [] , [] );
	for (my $j=0; $j<$n_children; $j++) {
	    $observed[0]->[$j] = $word_stats->{child_occurrences}->[$j] + 1;
	    $observed[1]->[$j] = $this->{'children_document_counts'}->[$j] + 1 - $observed[0]->[$j];
	}

	#my @expected = ( [] , [] );
	my $chi_square_statistic = 0;
	for (my $j=0; $j<$n_children; $j++) {
	    my $expected_0_j = ( $total_occurrences + $n_children )/ ( $total_documents + 2*$n_children ) * ( $this->{'children_document_counts'}->[$j] + 2 );
	    my $expected_1_j = ( $this->{'children_document_counts'}->[$j] + 2 ) - $expected_0_j;
	    $chi_square_statistic += ($observed[0]->[$j] - $expected_0_j)**2 / $expected_0_j;
	    $chi_square_statistic += ($observed[1]->[$j] - $expected_1_j)**2 / $expected_1_j;
	}

	if ( $chi_square_statistic < $chi_square_threshold ) {
	    $selected2score{$word} = $chi_square_statistic;
	}

    }

    return \%selected2score;

}

sub cross_entropy {

    my $p = shift;
    my $q = shift; 

    if ( !ref($p) ) {
	
	if ( !defined($q) ) {
	    die "problem: q is undef , with p --> $p";
	}

	if ( $p == 0 || $q == 1 ) {
	    return 0;
	}
	elsif ( $q == 0 ) {
	    return 999999999999999999999;
	}
	
	return ( -1 * $p * log($q) );
	
    }
    else {
	
	my $cross_entropy = 0;
	
	# map { $cross_entropy += -1 * $_ * log($_) } grep { $_ != 0 && $_ != 1 } values(%$p);
	my @events = keys(%$p);
	my $tiny = 0.00000000001;
	foreach my $event (@events) {
	    #$cross_entropy += cross_entropy($p->{$event}, $q->{$event} || 0);
	    $cross_entropy += -1 * $p->{$event} * log( $q->{$event} + $tiny );
	}
	
	return $cross_entropy;
	
    }

}

sub entropy {

    my $p = shift;
    
    if ( !ref($p) ) {

	if ( $p == 0 || $p == 1 ) {
	    return 0;
	}
	
	return ( -1 * $p * log($p) );
	
    }
    else {
	
	my $cross_entropy = 0;
	
	map { $cross_entropy += -1 * $_ * log($_) } grep { $_ != 0 && $_ != 1 } values(%$p);
	
	return $cross_entropy;
	
    }

}

# computes the mean and stddev of a set of values
sub mean_and_stddev {

    my $hash_ref = shift;

    my $n_entries = scalar(values(%$hash_ref));
    
    my $mean = 0;
    my $stddev = 0;

    if ( $n_entries > 0 ) {
	$mean = sum( values(%$hash_ref) ) / $n_entries;
	$stddev = sqrt( sum( map { ($_ - $mean)**2 } values(%$hash_ref) ) / $n_entries );
    }

    return ($mean, $stddev);

}

# computes mean and variance of a list of reals
sub _mean_and_variance {

    my $list = shift;

    my $n = scalar(@$list);
    if ( ! $n ) {
	return (0,0);
    }

    my $sum = 0;
    my $sum_square = 0;

    foreach my $element (@$list) {

	$sum += $element;
	$sum_square += $element**2;

    }

    my $e = $sum / $n;
    my $e2 = $sum_square / $n;

    my $var = max(0, $e2 - ($e**2));

    return ($e, $var);

}

1;
