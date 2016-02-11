package DataManagers::ContextCrawler;

use base ("DataManager");
use Carp;

#use Cache::FileCache;
use WWW::Mechanize;

# type of data produced by this data manager
sub data_type {
    return "context-source";
}

# download the context of a URL
sub run {
    my $this = shift;
    my $url_obj = shift;
    
    if ( $url_obj->{'context-cache'} ) {
	return 1;
    }
    else {
	$url_obj->{'context-cache'} = {};
    }

    # get context URLs
    my @context_urls = @{$url_obj->{'context'}};
    
    # create mech
    my $mech = WWW::Mechanize->new();
    $mech->timeout(5);
    $mech->agent_alias( 'Linux Mozilla' );

    # create cache
    # my $cache_root = $url_obj->get_data_directory() . "/context-cache/";
    # my $cache = new Cache::FileCache( { 'namespace' => $url_obj->url(),
    #					'default_expires_in' => $EXPIRES_NEVER,
    #					'cache_root' => $cache_root } );

    # read all urls in this file
    foreach my $context_url (@context_urls) {

	print STDERR "acquiring $context_url ...\n";

	# download URL content
	my $response = undef;
	my $content = undef;
	eval {
	    $response = $mech->get($context_url);
	};

#	print STDERR "after download for $context_url: $!\n";

	if ( ! $response || ! $mech->success() ) {
	    next;
	}

	$content = $response->decoded_content();

	if ( ! content ) {
	    next;
	}

	print STDERR "got content for $context_url, now storing into cache ...\n";

	# add this URL content to the cache
	# $cache->set($context_url, $content, $EXPIRES_NEVER);
	$url_obj->{'context-cache'}->{$context_url} = $content;

    }
    
    # close file
    close CONTEXT_URLS_FILE;

    return 1;
}

1;
