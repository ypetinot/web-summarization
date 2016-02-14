package ContentDistribution::HtmlTextAnalyzer;

use HTML::TreeBuilder;

sub content_distribution {

    my $html_text = shift;
    my $mode = shift;

    # extract plain text
    my $plain_text = '';

    eval {
	my $tree = HTML::TreeBuilder->new; # empty tree
	my $p = $tree->parse($html_text);
	$plain_text = $p->as_text;
	#$p->delete;
	$tree = $tree->delete;
    };

    return ContentDistribution::PlainTextAnalyzer::content_distribution($plain_text, $mode);
    
}

1;
