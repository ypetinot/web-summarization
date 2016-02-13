package DMOZ::Mapper::ContentBasedSummarizer;

# this summarizer exclusively relies on the content of the target to summarize it

# strategy 1: TF-IDF sentence selection

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use String::Similarity;

# processing method
sub process {

    my $this = shift;
    my $node = shift;

    my $url = $node->{url};

    my $summary = '';

    print STDERR "processing $url\n";

    # get content
    my $content = $node->get('content') || '';

    # get content distribution (content)
    my $content_distribution = ContentDistribution::generateFromContent($content, 'html');

    # get all the sentences in the document
    my $document = new Document($content);
    my $sentences = $document->getSentences();

    # now compute the importance of each sentence
    # ignore the fact that a sentence may be repeated (good)
    my %sentence2importance;
    foreach my sentence (@$sentences) {

	$sentence2importance{$sentence} = _importance($sentence, $content_distribution);

    }

    # rank sentences by decreasing importance
    my @sorted_sentences = sort { $sentence2importance{$b} <=> $sentence2importance{$a} } keys(%sentence2importance);

    if ( scalar(@sorted_sentences) ) {
	$summary = $sorted_sentences[0];
    }

    print join("\t", ($url, $summary)) . "\n";

}

1;

