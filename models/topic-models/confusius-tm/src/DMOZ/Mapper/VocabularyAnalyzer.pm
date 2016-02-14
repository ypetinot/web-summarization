package DMOZ::Mapper::VocabularyAnalyzer;

use strict;
use warnings;

# analyzes vocabulary used across all DMOZ entries (for a particular field ?) and
# strips words that appear only once

use FindBin;
my $WNHOME = "$FindBin::Bin/../../../third-party/local/";

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use Tokenizer;
use Vocabulary;

use List::MoreUtils qw/ uniq /;
use WordNet::QueryData;

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_vocabulary} = {};
    $this->{_wn} = WordNet::QueryData->new(
	dir => "$WNHOME/dict/",
	verbose => 0,
	noload => 1
	);

}

# processing method
sub process {

    my $this = shift;
    my $node = shift;

    # tokenize this entry's description
    my $tokens = Tokenizer->tokenize($node->{description});

    foreach my $token (@$tokens) {
	$this->{_vocabulary}->{$token}++;
    }
  
}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;

    my $appearance_threshold = 0;

    my $number_of_words_original = scalar(keys(%{ $this->{_vocabulary} }));
    print STDERR "[VocabularyAnalyzer] number of unique words: $number_of_words_original\n";

    # filter vocabulary, remove words that appear only once
    my %final_vocabulary;
#   $appearance_threshold = 10;
    foreach my $token (keys(%{ $this->{_vocabulary} })) {
#	if ( $this->{_vocabulary}->{$token} > $appearance_threshold ) {
	    $final_vocabulary{$token} = $this->{_vocabulary}->{$token};
#	}
    }

    # define set of vocabulary words
    my @voc = keys(%final_vocabulary);
    my $number_of_words = scalar(@voc);

    # determine the most likely POS tag for the selected vocabulary
    my @pos;
    my @alt_forms;
    map {
	my $v = $_;
	my ($pos, $alt) = $this->_get_pos($v);
	push @pos, $pos;
	push @alt_forms, ($v eq $alt)?undef:$alt;
    } @voc; 

    my $vocabulary = new Vocabulary(\@voc, \@pos, \@alt_forms);

    print STDERR "[VocabularyAnalyzer] number of unique words (count > $appearance_threshold): $number_of_words\n";

    $hierarchy->setProperty('vocabulary', $vocabulary);

}

# determine the most likely part of speech for a given word
sub _get_pos {

    my $this = shift;
    my $word = shift;

    # by default assume a Noun Phrase
    my $pos = 'u';
    my $lexeme = $word;

    if ( $word =~ m/\#/ ) {

    }
    else {

	my ($wn_data) = $this->{_wn}->validForms($word);
	if ( $wn_data && $wn_data =~ m/^(.*)\#(.*)/ ) {
	    $lexeme = $1;
	    $pos = $2;
	}

    }
    
    # return POS information
    return ($pos, $lexeme);

}

1;
