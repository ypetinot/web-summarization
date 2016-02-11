package OCELOT::BagOfWordsGister;

# implementation of the first gisting strategy proposed in \cite{Berger2000}.
# This gister computes a distribution of words (unigram model) from the
# input document's content and output the most likely gist given the corpus's
# gist length distribution.

use strict;
use warnings;

use OCELOT::Gister;

use base('OCELOT::Gister');

# constructor
sub new {

    my $that = shift;
    
    my $class = ref($that) || $that;

    my $object = SUPER::new();

    bless $object, $class;

    return $object;

}

# compute document word distribution
sub _html_2_word_distribution {

    my $this = shift;
    my $raw_html_content = shift;

    # render HTML content, produce list of sentences
    my @rendered_sentences = _render_html($raw_html_content);

    # compute language model (unigram model) based on this set of sentences
    # TODO: do we activate SOS/EOS symbols ?
    my $unigram_model = new NGramLanguageModel(1);
    foreach my $rendered_sentence (@rendered_sentences) {
	$unigram_model->update($rendered_sentence);
    }

    return $unigram_model;

}

# search for the best gist possible given a document
sub search {

    my $this = shift;
    my $document = shift;

    # get length distribution
    my $length_distribution = $this->getLengthDistribution();

    # get document content distribution
    # should this be through a method of the document class ?
    my $content_distribution = $this->_html_2_word_distribution($document->getRawContent());

    # perform Viterbi search
    my ($optimal_gist, $probability) = $this->_viterbi_search($length_distribution, $content_distribution);
    
    return $optimal_gist;

}

# perform viterbi search
# given an observed sequence of tokens (the document), what is the most likely sequence of hidden states
# (the gist words) that generated it.

# --> assume hidden-markov model
# --> events are in sequence
# --> hidden and observed sequences are aligned, one-to-one mapping
# --> t depends on t-1 only

sub _viterbi_search {

    my $this = shift;
    my $length_distribution = shift;
    my $content_distribution = shift;

    

    return (undef, 0);

}

1;
