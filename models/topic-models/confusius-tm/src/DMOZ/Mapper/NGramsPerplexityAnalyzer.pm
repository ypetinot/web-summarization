package DMOZ::Mapper::NGramsPerplexityAnalyzer;

use strict;
use warnings;

# computes perplexity of a set of DMOZ entries wrt specified model

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use List::Util qw/max/;

use NGramLanguageModel;
use Vocabulary;

# constructor
sub new {

    my $that = shift;
    my @sizes = @_;

    # instantiate super class
    my $ref = $that->SUPER::new();

    # store requested sizes
    $ref->{_ngrams} = {};
    map { $ref->{_ngrams}->{$_} = {} } @sizes;

    return $ref;

}

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    # instantiate vocabulary object
    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

    # instantiate language model
    #$this->{_language_model} = $hierarchy->instantiateModel($language_model, $params);

    my $max_size = max( keys(%{ $this->{_ngrams} }) );
    my $max_lm = NGramLanguageModel->loadServer($hierarchy->getPropertyDirectory('ngrams',$max_size));

    foreach my $size (keys(%{ $this->{_ngrams} })) {

#	$this->{_ngrams}->{$size}->{_language_model} = NGramLanguageModel->loadServer($hierarchy->getPropertyDirectory('ngrams',$size));
	$this->{_ngrams}->{$size}->{_language_model} = $max_lm;

	$this->{_ngrams}->{$size}->{_current_perplexity_sum} = 0;
	
    }

    $this->{_tmp_input} = File::Temp->new( UNLINK => 1 , SUFFIX => '.txt' );

    $this->{_current_count} = 0;
	
}

# processing method
sub process {

    my $this = shift;
    my $node = shift;

    # get sequence of tokens for this node
    my @tokens = @{ $node->get('description-tokens') };

    if ( !scalar(@tokens) ) {
	return;
    }

    # map tokens to their ids
    my @token_ids = map { $this->{_vocabulary}->word_index($_) } @tokens;

    foreach my $size (keys(%{ $this->{_ngrams} })) {

	# get language model probability for this sequence of tokens
	my $sequence_perplexity = $this->{_ngrams}->{$size}->{_language_model}->perplexity($size, \@token_ids);

=pod
    # soooo inefficient right now !
	# store perplexity info
	$node->set_hash('perplexity', 'ngrams-' . $size, $sequence_perplexity);
=cut	

	print join("\t", $node->name(), $size, $sequence_perplexity) . "\n";

	# update aggregate variables
	$this->{_ngrams}->{$size}->{_current_perplexity_sum} += $sequence_perplexity;
	
    }

    $this->{_current_count}++;
    
}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;

    foreach my $size (keys(%{ $this->{_ngrams} })) {
	
	my $perplexity = 0;
	if ( $this->{_current_count} ) {
	    $perplexity = $this->{_ngrams}->{$size}->{_current_perplexity_sum} / $this->{_current_count};
	}
	
	print STDERR "[$size] perplexity: $perplexity\n";

    }

    print STDERR "count is: " . $this->{_current_count} . "\n";

}

1;

