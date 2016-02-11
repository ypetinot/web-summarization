package ContextBasedSummarizer;

# to look at
# http://search.cpan.org/~mhamilton/WebCache-Digest-1.00/
# http://search.cpan.org/~awrigley/sitemapper-1.019/lib/WWW/Sitemap.pm

# base class for all context-based summarizers

use URI;

# constructor
sub new {
    my $package = ref($_) || $_;
    my $hash = ();
    bless $hash, $package;
}



# summarize a URL
sub summarize {
    my $this = shift;
    my $url = shift;

    # url is expected to be an instance of URI
    if ( ref($url) ne 'URI' ) {
	croak "invalid URL object";
    }
    
    # acquire the context for the target url
    my $context = $this->getContext($url);

    # generate summary for the target url, given its context
    my $summary = $this->summarizeByContext($url, $context);

    return $summary;
}

1;
