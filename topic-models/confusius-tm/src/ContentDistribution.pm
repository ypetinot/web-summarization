package ContentDistribution;

use strict;
use warnings;

# Abstract class that gives access to frequency information

use Data::Dumper;

use ContentDistribution::HtmlTextAnalyzer;
use ContentDistribution::PlainTextAnalyzer;

sub generate {

    my $source_file = shift;
    my $source_type = shift;

    # read content
    my $content = '';
    {
	local $/ = undef;
	open CONTENT_FILE, $source_file or die "Unable to open content file $content: $!";
	$content = <CONTENT_FILE>;
	close CONTENT_FILE;
    }

    return generateFromContent($content, $source_type);

}

sub generateFromContent {

    my $content = shift;
    my $content_type = shift;

    my $distribution = undef;

    if ( $content_type eq 'html' ) {
	$distribution = ContentDistribution::HtmlTextAnalyzer::content_distribution($content);
    }
    else {
	$distribution = ContentDistribution::PlainTextAnalyzer::content_distribution($content);
    }

    return $distribution;

}

sub generateFromTokens {

    my $tokens = shift;
    my $distribution = ContentDistribution::TokenAnalyzer::content_distribution($tokens);

    return $distribution;

}

sub loadFromFile {

    my $file_path = shift;

    my $obj = undef;

    no strict;

    local $/ = undef;
    open FILE, $file_path or die "Unable to open file $file_path: $!";
    my $content = <FILE>;
    $obj = eval($content);
    if ( $@ ) {
	print STDERR "Problem while loading model file: $@\n";
    }
    close FILE;

    return $obj;

}

sub new {

    my $that = shift;
    my $tfs = shift;
    my $dfs = shift;
    my $n_documents = shift;
    my $n_words = shift;
    my $smoothing_mode = shift;

    my $class = ref($that) || $that;

    my $hash = {};

    $hash->{_token_stats} = _build_token_stats($tfs, $dfs);
    $hash->{_n_docs} = $n_documents;
    $hash->{_n_words} = $n_words;
    $hash->{_smoothing_mode} = $smoothing_mode;

    bless $hash, $class;

    return $hash;

}

# private - build token stats
sub _build_token_stats {

    my $tfs = shift;
    my $dfs = shift;

    # compute ranking information
    my $rank_cursor = 0;
    my $score_previous = 0;
    my $scoring_function = sub{ my $token = shift; return $tfs->{$token}; };
    my %ranks;
    map {
	if ( $scoring_function->($_) != $score_previous ) { 
	    $rank_cursor++;
	}
	$ranks{$_} = $rank_cursor;
	$score_previous = $scoring_function->($_);
    } sort { $scoring_function->($b) <=> $scoring_function->($a) } keys(%{$tfs});
    
    my %token_stats;    
    
    map { $token_stats{$_} = {
	tfs => $tfs->{$_},
	dfs => $dfs->{$_},
	rank => $ranks{$_},
	  }
    } 
    keys( %{$tfs} );
    
    return \%token_stats;

}

# set/get name
sub name {

    my $this = shift;
    my $value = shift;

    if ( defined($value) ) {
	$this->{_name} = $value;
    }

    return $this->{_name};

}

# get list of words in this distribution
sub words {

    my $this = shift;

    my @words = keys(%{$this->{_token_stats}});

    return \@words;

}

# get the rank of a particular word in this distribution
sub word_rank {

    my $this = shift;
    my $word = shift;

    my $rank = $this->{_token_stats}->{$word}->{rank};

    return $rank;

}

# get the probability of a particular word in this distribution
sub probability {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    return $this->distribution->{$word} || 0;

}

# get the tf score a particular word in this distribution
sub tf {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    my $tf = $this->{_token_stats}->{$word}->{tfs} || 0;

    return $tf;

}

# get the df score a particular word in this distribution
sub df {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    my $df = $this->{_token_stats}->{$word}->{dfs} || 0;

    return $df;

} 

# get the tf-idf score of a particular word in this distribution
sub tfidf {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    # use probability function instead ?
    my $tf = $this->distribution->{$word} || 0;
    
    if ( ! $tf ) {
	return 0;
    }

    my $raw_df = $this->{_token_stats}->{dfs}->{$word};

    return ( $tf * ( log( $this->{_n_docs} / $raw_df) ) );

}

# get number of documents on which this distribution has been computed
sub number_of_documents {

    my $this = shift;
    
    return $this->{_n_docs};

}

# get number of words based on which this distribution has been computed
# accounts for multiple occurrences of a given word
sub number_of_words {

    my $this = shift;

    return $this->{_n_words};

}

# get term frequencies
sub frequencies {

    my $this = shift;

    my %frequencies = ( map { $_ => $this->{_token_stats}->{$_}->{tfs} } keys( %{ $this->{_token_stats} } ) );

    return \%frequencies;

}

# get document frequencies
sub document_frequencies {

    my $this = shift;
    
    my %document_frequencies = ( map { $_ => $this->{_token_stats}->{$_}->{dfs} } keys( %{ $this->{_token_stats} } ) );

    return \%document_frequencies;

}

# probability mass function
sub distribution {

    my $this = shift;
    my $n = shift;

    my %distribution = %{ $this->frequencies };

    map { $distribution{$_} = $distribution{$_} / $this->{_n_words} } keys(%distribution);

    if ( defined($n) && ($n < scalar(keys(%distribution))) ) {
	my @sorted_keys = sort { $distribution{$b} <=> $distribution{$a} } keys(%distribution);
	splice @sorted_keys, $n;
	my %temp_distribution;
	map { $temp_distribution{$_} = $distribution{$_}; } @sorted_keys;
	%distribution = %temp_distribution;
    }

    return \%distribution;

}

# distribution of tfidf scores
# TODO: can we avoid code repetition with function above ?
sub distribution_tfidf {

    my $this = shift;
    my $n = shift;

    my %distribution;

    # generate all tfidf scores
    map { $distribution{$_} = $this->tfidf($_); } @{$this->words};

    # sort
    my @sorted_words = sort { $distribution{$b} <=> $distribution{$a} } keys(%distribution);
    
    # truncate to preserve only the top $n words
    if ( defined($n) && ($n < scalar(keys(%distribution))) ) {
	my @sorted_keys = sort { $distribution{$b} <=> $distribution{$a} } keys(%distribution);
	splice @sorted_keys, $n;
	my %temp_distribution;
	map { $temp_distribution{$_} = $distribution{$_}; } @sorted_keys;
	%distribution = %temp_distribution;
    }

    return \%distribution;

}

# refine distribution
sub refine {

    my $this = shift;
    my $n = shift;
    my $type = shift;

    my %keep;
    if ( defined($type) && ($type eq 'tfidf') ) {
	%keep = %{ $this->distribution_tfidf($n) };
    }
    else {
	%keep = %{ $this->distribution($n) };
    }

    # remove all tokens that are not in the keep distribution
    my @remove = grep { !defined($keep{$_}) } @{ $this->words };
    $this->removeFromDistribution(\@remove);

}

# dump summary of this distribution
sub dump_distribution {

    my $this = shift;
    my $n = shift;
    my $type = shift;

    my $dist = undef;
    if ( defined($type) && ($type eq 'tfidf') ) {
	$dist = $this->distribution_tfidf($n);
    }
    else {
	$dist = $this->distribution($n);
    }

    return join(" ", map { $_ . ":" . $dist->{$_} } sort { $dist->{$b} <=> $dist->{$a} } keys(%$dist) );

}

# merge two distributions
sub merge_distributions {

    my $dist1 = shift;
    my $dist2 = shift;

    my $new_n_docs = $dist1->number_of_documents + $dist2->number_of_documents;
    my $new_n_words = $dist1->number_of_words + $dist2->number_of_words;

    # collect original term frequencies
    my $tfs1 = $dist1->frequencies;
    my $tfs2 = $dist2->frequencies;

    # collect original document frequencies
    my $dfs1 = $dist1->document_frequencies;
    my $dfs2 = $dist2->document_frequencies;

    my %all_tokens;
    my %all_documents;
    map { $all_tokens{$_} += $tfs1->{$_}; $all_documents{$_} += $dfs1->{$_}; } keys(%{$tfs1});
    map { $all_tokens{$_} += $tfs2->{$_}; $all_documents{$_} += $dfs2->{$_}; } keys(%{$tfs2});

    return new ContentDistribution(\%all_tokens, \%all_documents, $new_n_docs, $new_n_words, undef);

}

# remove specified tokens from the distribution (does not affect the number of documents)
sub removeFromDistribution {

    my $this = shift;
    my $tokens = shift;

    foreach my $token (@$tokens) {
	
	# remove document frequency info
	if ( defined($this->{_token_stats}->{$token}) ) {
	    delete $this->{_token_stats}->{$token};
	}
	
    }

    return $this;

}

# compute KL Divergence with respect to this distribution
sub KLDivergence {

    my $this = shift;
    my $distribution = shift;

    #sum (P(i) * log(P(i)/Q(i))

    my $sum = 0;
    foreach my $word (@{$this->words()}) {

	# TODO: use +1 smoothing 
	$sum += log( $this->probability($word) / ( $distribution->probability($word) + 1 ) );
	
    }  

    return $sum;

}

1;
