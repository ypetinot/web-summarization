package VectorContentDistribution;

use strict;
use warnings;

# Abstract class that gives access to frequency information

use Data::Dumper;

use ContentDistribution::HtmlTextAnalyzer;
use ContentDistribution::PlainTextAnalyzer;
use Vocabulary;

sub generate {

    my $source_file = shift;
    my $source_type = shift;
    my $vocabulary  = shift;

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
    my $vocabulary = shift;

    my $tokens = undef;

    if ( $content_type eq 'html' ) {
	$tokens = ContentDistribution::HtmlTextAnalyzer::content_distribution($content);
    }
    else {
	$tokens = ContentDistribution::PlainTextAnalyzer::content_distribution($content);
    }

    return build_from_tokens($tokens, $vocabulary);

}

sub generateFromTokens {

    my $tokens = shift;
    my $vocabulary = shift;

    return build_from_tokens($tokens, $vocabulary);

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


# build content distribution from tokens
sub build_from_tokens {

    my $tokens = shift;
    my $vocabulary = shift;
    my $mode = shift || undef; # not used for now
    
    # compute token frequencies
    my %token_frequencies;
    map { $token_frequencies{$_}++ } @$tokens;

    # map token frequencies into a vector
    my %vocabulary_tfs;
    my $i = 0;
    foreach my $token (@$tokens) {

	#my $word_index = $vocabulary->word_index($token);
	my $word_index = $token;
	if ( defined($word_index) ) {
	    $vocabulary_tfs{$word_index} = $token_frequencies{$token};
	}

    }

    # compute document frequences (easy)
    my %document_frequencies;
    map { $document_frequencies{$_} = 1 } keys(%token_frequencies);

    # map token frequencies into a vector
    my %vocabulary_dfs;
    my $j = 0;
    foreach my $token (@$tokens) {

	# my $word_index = $vocabulary->word_index($token);
	my $word_index = $token;
	if ( defined($word_index) ) {
	    $vocabulary_dfs{$word_index} = $document_frequencies{$token}
	}

    }

    # return Content Distribution instance
    return new VectorContentDistribution(\%vocabulary_tfs, \%vocabulary_dfs, scalar(@$tokens), 1, undef);

}

sub new {

    my $that = shift;
    my $tfs = shift;
    my $dfs = shift;
    my $n_words = shift;
    my $n_documents = shift;
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

    return { 'tfs' => $tfs , 'dfs' => $dfs };

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

    # my @words = keys(%{$this->{_token_stats}});
    my @words;
    foreach my $key (keys(%{ $this->{_token_stats}->{tfs} })) {
	    push @words, $key;
    }

    return \@words;

}

# get the probability of a particular word in this distribution
sub probability {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    return ( $this->tf($word) /  $this->number_of_words() ) || 0;

}

# get the tf score a particular word in this distribution
sub tf {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    my $tf = $this->{_token_stats}->{tfs}->{$word} || 0;

    return $tf;

}

# get the df score a particular word in this distribution
sub df {

    my $this = shift;
    my $word = shift;

    # TODO: normalize word

    my $df = $this->{_token_stats}->{dfs}->{$word} || 0;

    return $df;

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

    return $this->{_token_stats}->{tfs};

}

# get document frequencies
sub document_frequencies {

    my $this = shift;
        
    return $this->{_token_stats}->{dfs};

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
    foreach my $hash_ref ( [$tfs1,$dfs1] , [$tfs2,$dfs2] ) {
	foreach my $key (keys %{$hash_ref->[0]}) {
	    if ( !defined($all_tokens{$key}) ) { $all_tokens{$key} = 0; }
	    $all_tokens{$key}    += $hash_ref->[0]->{$key};
	    if ( !defined($all_documents{$key}) ) { $all_documents{$key} = 0; }
	    $all_documents{$key} += $hash_ref->[1]->{$key};
	}
}
    return new VectorContentDistribution(\%all_tokens, \%all_documents, $new_n_words, $new_n_docs, undef);

}

1;
