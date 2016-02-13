package DMOZ::Mapper::WordAssignment;

use strict;
use warnings;

use Data::Dumper;
use Statistics::Basic qw/mean stddev/;

use VectorContentDistribution;
use DMOZ::Mapper;
use DMOZ::WordAssigner;

# TODO: this is not a mapper
use base qw(DMOZ::Mapper);

local $| = 1;
binmode(STDOUT, ":utf8");

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');
    $this->{_OOV_TOKEN} = $this->{_vocabulary}->word_index('OOV');

}

# pre-processing method
# requires that all nodes have been annotated with their content-distribution
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;
    
    # for each word we need to decide whether it is strongly correlated with exactly one of the
    # children nodes. If that is the case, then this word is not kept, otherwise it is assigned
    # as being representative of the current level

    my $depth = scalar(@$path);
    my $node_content_distribution = $node->get('content-distribution');
    my @node_content_distribution_words = @{ $node_content_distribution->words() };

    my $total_documents = $node_content_distribution->number_of_documents();

    my @children_nodes = @{ $node->getChildren() };

    my @words = grep {
	$node_content_distribution->tf($_) && (!_is_already_assigned($_, $data))
    } @node_content_distribution_words;

    my @word_assignment;
    my @word_assignment_full;
    my %final_word_assignment;

    my %word2score;

    my @children_content_distributions = map { $_->get('content-distribution'); } @children_nodes;
    my @children_names = map { $_->name(); } @children_content_distributions;
    my @children_document_counts = map { $_->number_of_documents(); } @children_content_distributions;

    # we are mostly interested in category nodes with at least 2 children
    if ( scalar(@children_nodes) > 1 ) {

	# words are kept at this level if they do not help in the N-way classification task among
	# this node's children, this is therefore akin to the feature selection process
	# therefore if a word is helpful to perform classification wrt any of the children, it cannot be kept
	# at this level
	my $word_assigner = new DMOZ::WordAssigner($total_documents, \@children_document_counts);
	foreach my $word (@words) {

	    my %word_stats;
	    $word_stats{'total_occurrences'} = $node_content_distribution->df($word);
	    $word_stats{'child_occurrences'} = [];

	    # collect child-specfic statistics 
	    for (my $i=0; $i<scalar(@children_nodes); $i++) {
		push @{$word_stats{'child_occurrences'}}, $children_content_distributions[$i]->df($word);
	    }

	    $word_assigner->set_word_stats($word, \%word_stats);
	    
	}

	# now perform word selection
	# TODO: can mode become a parameter ?
	my $mode = $this->{mode};
	print STDERR "[WordAssignment] mode: $mode\n";
	my $word_selection = $word_assigner->select($mode,$node->name,$depth);
	foreach my $word (keys(%$word_selection)) {
	    push @word_assignment_full, $word;
	    $word2score{$word} = $word_selection->{$word};
	}
	    
	@word_assignment = sort { $word2score{$a} <=> $word2score{$b} } grep { $_ ne $this->{_OOV_TOKEN} } @word_assignment_full;
	
    }
    elsif ( $node->type() eq 'entry' ) {
	@word_assignment = @words;
    }
    else {
	# the remaining case is where a node has exactly one child, in which case all the words should be
	# assigned to the child node, so @word_assignment remains empty
	# print STDERR "assignment problem @ " . $node->name . "\n";
    }

    print STDERR $node->name . " [$total_documents] --> " . join (" - ", map { join(":", ($this->{_vocabulary}->get_word($_), ($word2score{$_}||0))) } @word_assignment) . "\n";
    print STDERR "\n";
    
    map { $final_word_assignment{$_} = 1; } @word_assignment;
    $node->set('word-assignment', \%final_word_assignment);

    return \%final_word_assignment;

=pod
    # verification check for entry nodes
    if ( $node->type() eq 'entry' ) {

	foreach my $word (@node_content_distribution_words) {

	    my $word_found = 0;

	    foreach my $ancestor_word_assignment (@$data) {
		$word_found += $ancestor_word_assignment->{$word} || 0;
	    }
	    
	    if ( $word_found != 1 ) {
		
		my $status_not_found = undef;
		if ( $word_found > 1 ) {
		    $status_not_found = "multiple occurrences";
		}
		else {
		    $status_not_found = "no occurrence";
		}

		print STDERR "[" . $node->name . "] $word has invalid status: $status_not_found\n";

	    }

	}
	
    }
=cut

}

# post-processing method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    # nothing
    
}

# checks whether a word has been assigned to an ancestor
sub _is_already_assigned {

    my $word = shift;
    my $path_data = shift;

    my @path_assignments = @$path_data;

    my $n_assignments = 0;
    foreach my $path_assignment (@path_assignments) {

	if ( $path_assignment->{$word} ) {
	    $n_assignments++;
	    # return 1;
	}

    }

    if ( $n_assignments > 1 ) {
	print STDERR "word $word has been assigned to multiple levels\n";
    }

    #return 0;
    return $n_assignments;

}

1;

=pod

    # What I once thought was good stuff !

    		# chi-square
		my $pt = ($ntc_10 + $ntc_11) / $total_documents;
		my $pc = ($ntc_01 + $ntc_11) / $total_documents;
		
		my $etc_00 = $total_documents * (1 - $pt) * (1 - $pc);
		my $etc_10 = $total_documents * $pt       * (1 - $pc);
		my $etc_01 = $total_documents * (1 - $pt) * $pc;
		my $etc_11 = $total_documents * $pt       * $pc;
		
		my $chi_square = 0;
		if ( !$etc_00 || !$etc_10 || !$etc_01 || !$etc_11 ) {

		    # what do we do here, case where we cannot compute the chi-square score

		}
		else {
		    
		    $chi_square = (( ($ntc_00 - $etc_00)**2 ) / $etc_00 ) +
			(( ($ntc_10 - $etc_10)**2 ) / $etc_10 ) +
			(( ($ntc_01 - $etc_01)**2 ) / $etc_01 ) +
			(( ($ntc_11 - $etc_11)**2 ) / $etc_11 );
		    
		    # check whether the current word and the current category can be considered independent
		    #if ( $chi_square > 6.63 ) {
		    #    $skip = 1;
		    #}
		    #else {
		    #    # nothing
		    #}
		    
		}
						
		# mutual information: p(x,y) * log(p(x,y)/p(x)p(y))
		# my $p_x_y = $ntc_11 / $child_documents; --> this was probably not accurate
		my $p_x_y = $ntc_11 / $total_documents;
		my $p_nx_y = $ntc_01 / $total_documents;
		my $p_x_ny = $ntc_10 / $total_documents;
		my $p_nx_ny = $ntc_00 / $total_documents;

		my $p_x = $pt;
		my $p_y = $pc;
		
		#my $mutual_information = 0;
		#if ( $p_x_y && $p_x && $p_y ) {
		#    $mutual_information = $p_x_y * log($p_x_y / ($p_x * $p_y));
		#}
		
		#$word2mi{$word} = min($word2mi{$word} || $mutual_information, $mutual_information);
		
		# entropy: \sum(p(c) * log(p(t|c)
		
		# IG = H(c) - H(c|t)
		# my $entropy_c = ($pc == 1 || $pc == 0)?0:(-1 * $pc * log( $pc )); # entropy of the current category
		# my $entropy_ct = ($p_xy == 1 || $p_xy == 0)?0:(-1*($p_xy)*log($p_xy));
		my $entropy_c = entropy($pc) + entropy(1-$pc);
		my $entropy_ct = entropy($p_x_y) + entropy($p_nx_y) + entropy($p_x_ny) + entropy($p_nx_ny);  
		#if ( $entropy_ct > $entropy_c ) {
		#    die "problem: $word - $entropy_c - $entropy_ct";
		#}


		my $information_gain = $entropy_c - $entropy_ct;
		#$word2ig{$word} = min($word2ig{$word} || $information_gain, $information_gain);
		#$word2ig{$word} += ($child_documents / $total_documents) * $information_gain;
		$word2ig{$word} += $information_gain;
		$word2minig{$word} = defined($word2minig{$word})?min($word2minig{$word},$information_gain):$information_gain;
		$word2maxig{$word} = defined($word2maxig{$word})?max($word2maxig{$word},$information_gain):$information_gain;
		#$word2ig{$word} = max($word2ig{$word} || $information_gain, $information_gain);

		#for my $variable (("yves", "chi")) {
		#	print STDERR "($variable ga r wo hatsuon dekiru ka)?(tori ga ureshii):(tori ga bakuhatsu)\n";
		#}
		
		# this is a "one-of classification" problem


	my $mean_mutual_information = 0;
	if ( scalar(keys(%word2mi)) ) {
	    map { $mean_mutual_information += $word2mi{$_} || 0; } keys(%word2mi);
	    $mean_mutual_information /= scalar(keys(%word2mi));
	}
	
	# compute the mean and the variance of the mutual information at this level
	my @all_mi = values(%word2mi);
	my ($mi_mean, $mi_variance) = _mean_and_variance(\@all_mi);
	my $mi_std_dev = sqrt($mi_variance);
		
	# compute the mean and the variance of the information gain at this level
	map { $word2ig{$_} /= scalar(@children_nodes) } keys(%word2ig);
	my @all_ig = values(%word2ig);
	my ($ig_mean, $ig_variance) = _mean_and_variance(\@all_ig);
	my $ig_std_dev = sqrt($ig_variance);

	# the words that are independent of any one of the children category are kept at this level
	#@word_assignment = grep { defined($word2skip{$_}) && $word2skip{$_} > $mean_correlation_number } @words;
	#@word_assignment = grep { ( $word2skip{$_} / scalar(@children_nodes) ) > 10 } @words;
	#@word_assignment = grep { $word2skip{$_} > 108 } @words;
	#@word_assignment = grep { $word2mi{$_} > 1 } @words;
	#@word_assignment = grep { $word2mi{$_} < $mi_mean } @words;
	#@word_assignment = grep { $word2entropy{$_} > ( $entropy_mean + 1/exp($depth) * $entropy_std_dev ) } @words; 
	#@word_assignment = grep { $word2mi{$_} > $mean_mutual_information } @words;
	
	#print "[all: $ig_mean / $ig_std_dev] " . $node->name . " --> " . join (" - ", map { "$_:$word2ig{$_}" } @words) . "\n";  
	
	# keep words that have a comparatively low information gain
	# my @word_assignment_full = sort { $word2ig{$b} <=> $word2ig{$a} } grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2ig{$_} < 0) && ($ig_mean >= $word2ig{$_}) && ($ig_mean - $word2ig{$_} > 3 * $ig_std_dev) } @words;
	#my @word_assignment_full = sort { $word2ig{$b} <=> $word2ig{$a} } grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2ig{$_} <= 0) } @words;
	#my @word_assignment_full = sort { $word2ig{$b} <=> $word2ig{$a} } grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2uniqueChildrenCount{$_} > 1) && ($word2ig{$_} <= -0.2) } @words;
	
	#my $min_ig = min( map { $word2maxig{$_} } @words );
	#my $target_children_count = max( values %word2uniqueChildrenCount );
	#my $mean_ig = mean( values(%word2ig) );
	#my @word_assignment_full = sort { $word2ig{$b} <=> $word2ig{$a} } grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2uniqueChildrenCount{$_} > 1) && ($word2maxig{$_} <= 0) && ( $min_ig / 10 > $word2maxig{$_} )} @words;
	#my @word_assignment_full = sort { $word2ig{$b} <=> $word2ig{$a} } grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2ig{$_} <= 0) && ($word2ig{$_} < $mean_ig) } @words;
	

	# this does not work well at all !
	#my @word_assignment_full = grep { $_ ne $this->{_OOV_TOKEN} } grep { ($word2minig{$_} <= 0) } @words;

=cut

=pod

	# compute chi-square for this word for every possible pair of children
	foreach my $child_node (@children_nodes) {
	    
	    my $child_content_distribution = $child_node->get('content-distribution');
	    
	    if ( ! $child_content_distribution ) {
		print STDERR "[WordAssignment] missing content-distribution for node " . $child_node->name() . "\n";
		next;
	    }
	    
	    my $child_documents = $child_content_distribution->number_of_documents();
	    
	    foreach my $word (@words) {
		
		my $total_occurrences = $node_content_distribution->df($word);
		my $child_occurrences = $child_content_distribution->df($word);
		
		my $ntc_00 = ($total_documents - $child_documents) - ($total_occurrences - $child_occurrences);
		my $ntc_10 = $total_occurrences - $child_occurrences;
		my $ntc_01 = $child_documents - $child_occurrences;
		my $ntc_11 = $child_occurrences;
		
		my $pt = ($ntc_10 + $ntc_11) / $total_documents;
		my $pc = ($ntc_01 + $ntc_11) / $total_documents;
		
		my $etc_00 = $total_documents * (1 - $pt) * (1 - $pc);
		my $etc_10 = $total_documents * $pt       * (1 - $pc);
		my $etc_01 = $total_documents * (1 - $pt) * $pc;
		my $etc_11 = $total_documents * $pt       * $pc;
		
		my $chi_square_max = 15;
		my $chi_square = 0;
		my $skip = 0;
		if ( !$etc_00 || !$etc_10 || !$etc_01 || !$etc_11 ) {
		    $skip = 1;
		}
		else {
		    
		    $chi_square = (( ($ntc_00 - $etc_00)**2 ) / $etc_00 ) +
			(( ($ntc_10 - $etc_10)**2 ) / $etc_10 ) +
			(( ($ntc_01 - $etc_01)**2 ) / $etc_01 ) +
			(( ($ntc_11 - $etc_11)**2 ) / $etc_11 );
		    
		    # check whether the current word and the current category can be considered independent
		    #if ( $chi_square > 6.63 ) {
		    #    $skip = 1;
		    #}
		    #else {
		    #    # nothing
		    #}
		    
		}
		
		#if ( $skip ) {
		#if ( !defined($word2skip{$word}) ) {
		#    $word2skip{$word} = [];
		#}
		#push @{$word2skip{$word}}, $child_node->name;
		#$word2skip{$word}++;
		#}
		
		#$word2skip{$word} += $chi_square;
		$word2skip{$word} = max($word2skip{$word} || $chi_square, $chi_square);
		
		# mutual information: p(x,y) * log(p(x,y)/p(x)p(y))
		my $p_xy = $ntc_11 / $child_documents;
		my $p_x = $pt;
		my $p_y = $pc;
		
		#if ( !defined($word2mi{$word}) ) {
		#	$word2mi{$word} = [];
		#}
		
		my $mutual_information = 0;
		if ( $p_xy && $p_x && $p_y ) {
		    $mutual_information = $p_xy * log($p_xy / ($p_x * $p_y));
		}
		
		$word2mi{$word} = min($word2mi{$word} || $mutual_information, $mutual_information);
		#push @{ $word2mi{$word} }, $mutual_information;
		
		# entropy: \sum(p(c) * log(p(t|c)
		my $tiny =  0.0000000000001;
		my $smoothed_p_xy = ($p_xy !=1)?($p_xy + $tiny):($p_xy - $tiny);
		$word2entropy{$word} += ($child_documents / $total_documents) * ( log($smoothed_p_xy) + log( 1- $smoothed_p_xy) );
		
		# IG = H(c) - H(c|t)
		my $entropy_c = ($pc == 1 || $pc == 0)?0:(-1 * $pc * log( $pc )); # entropy of the current category
		my $entropy_ct = ($p_xy == 1 || $p_xy == 0)?0:(-1*($p_xy)*log($p_xy));  
		#if ( $entropy_ct > $entropy_c ) {
		#    die "problem: $word - $entropy_c - $entropy_ct";
		#}

		my $information_gain = $entropy_c - $entropy_ct;
		#$word2ig{$word} = min($word2ig{$word} || $information_gain, $information_gain);
		#$word2ig{$word} += ($child_documents / $total_documents) * $information_gain;
		$word2ig{$word} +=

		#for my $variable (("yves", "chi")) {
		#	print STDERR "($variable ga r wo hatsuon dekiru ka)?(tori ga ureshii):(tori ga bakuhatsu)\n";
		#}
		
		# words are kept at this level if they do not help in the N-way classification task among
		# this node's children, this is therefore akin to the feature selection process
		# therefore if a word is helpful to perform classification wrt any of the children, it cannot be kept
		# at this level
		
		# this is a "one-of classification" problem
		
		# first implementation: chi-square
		
	    }
	    
	}

	my $mean_correlation_number = 0;
	if ( scalar(keys(%word2skip)) ) {
	    
	    # compute the mean number of categories that are judged to be correlated with any particular word
	    map { $mean_correlation_number += $word2skip{$_} || 0; } keys(%word2skip);
	    $mean_correlation_number /= scalar(keys(%word2skip));
	    
	}
	
	my $mean_mutual_information = 0;
	if ( scalar(keys(%word2mi)) ) {
	    
	    map { $mean_mutual_information += $word2mi{$_} || 0; } keys(%word2mi);
	    $mean_mutual_information /= scalar(keys(%word2mi));
	    
	}
	
	# compute the mean and the variance of the mutual information at this level
	my @all_mi = values(%word2mi);
	my ($mi_mean, $mi_variance) = _mean_and_variance(\@all_mi);
	my $mi_std_dev = sqrt($mi_variance);
	
	# compute the mean and the variance of the entropy at this level
	my @all_entropy = values(%word2entropy);
	my ($entropy_mean, $entropy_variance) = _mean_and_variance(\@all_entropy);
	my $entropy_std_dev = sqrt($entropy_variance);
	
	# compute the mean and the variance of the information gain at this level
	map { $word2ig{$_} /= scalar(@children_nodes) } keys(%word2ig);
	my @all_ig = values(%word2ig);
	my ($ig_mean, $ig_variance) = _mean_and_variance(\@all_ig);
	my $ig_std_dev = sqrt($ig_variance);
	
	# the words that are independent of any one of the children category are kept at this level
	#@word_assignment = grep { defined($word2skip{$_}) && $word2skip{$_} > $mean_correlation_number } @words;
	#@word_assignment = grep { ( $word2skip{$_} / scalar(@children_nodes) ) > 10 } @words;
	#@word_assignment = grep { $word2skip{$_} > 108 } @words;
	#@word_assignment = grep { $word2mi{$_} > 1 } @words;
	#@word_assignment = grep { $word2mi{$_} > ($mi_mean + $mi_std_dev) } @words;
	#@word_assignment = grep { $word2entropy{$_} > ( $entropy_mean + 1/exp($depth) * $entropy_std_dev ) } @words; 
	#@word_assignment = grep { $word2mi{$_} > $mean_mutual_information } @words;
	
	#print "[all: $ig_mean / $ig_std_dev] " . $node->name . " --> " . join (" - ", map { "$_:$word2ig{$_}" } @words) . "\n";  
	
	# keep words that have a comparatively low information gain
	@word_assignment = grep { ($ig_mean >= $word2ig{$_}) && ($ig_mean - $word2ig{$_} > 3 * $ig_std_dev) } @words;
	
	#@word_assignment = grep { $word2mi{$_} > 5*$mean_mutual_information } @words;
	
	if ( scalar(@word_assignment) ) {
	    print $node->name . " --> " . join (" - ", map { "$_:$word2ig{$_}" } @word_assignment) . "\n";
	}  

    for my $word ((1,19,221,446)) {
	print STDERR "[WordAssignment] information gain '" . $this->{_vocabulary}->get_word($word) . "': " . join(" | ", $word2ig{$word}, $entropy_p_w_c{$word}, $word2uniqueChildrenCount{$word}) . "\n";
    }


=cut
