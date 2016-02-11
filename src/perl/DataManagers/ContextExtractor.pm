package DataManagers::ContextExtractor;

use base ("DataManager");

use Carp;
use Encode;
use URI;
use URI::URL;
use Lingua::EN::Sentence qw( get_sentences add_acronyms set_EOS );
#use Text::Sentence qw( split_sentences );
use XML::TreePP;
#use Text::Iconv;
use Cache::FileCache;
use HTML::FormatText::Lynx;
use File::Temp qw/tempfile/;
use JSON;

use warnings;
use strict;

use utf8;

# type of data produced by this data manager
sub data_type {
    return "full-context.xml";
}

# aqcuire the context of a URL
sub run {
    my $this = shift;
    my $url_obj = shift;

    my $url_name = $url_obj->url(); #TODO: overload scalar context please !

    # my $cache_location = $url_obj->get_file('context-cache');
    my $cache_location = $url_obj->{_data_file};

    #my $context = `export CONTEXT_SUMMARIZATION_ROOT=$ENV{CONTEXT_SUMMARIZATION_ROOT} && export CONTEXT_SUMMARIZATION_COMMON_ROOT=$ENV{CONTEXT_SUMMARIZATION_COMMON_ROOT} && . $project_env > /dev/null && . $common_env > /dev/null && get-context-anchortext --mode full --output xml '$url_name' $cache_location`;

    my $context = extract($url_name, $cache_location, 'full', 'xml');

    # write-out context
    my $full_context_file = $url_obj->{_data_file};
    $full_context_file =~ s/url$/$this->data_type()/se;
    open FULL_CONTEXT, ">$full_context_file" or die "unable to create full context file $full_context_file: $!";
    print FULL_CONTEXT $context;
    close FULL_CONTEXT;

    return 1;
}

my $link_marker = "__link__";

# create user agent
$main::mech = WWW::Mechanize->new();
$main::mech->timeout(5);
$main::mech->agent_alias( 'Linux Mozilla' );

# extract context
sub extract {
    
    my $target_url = shift;
    my $context_urls_file = shift;
    my $mode = shift;
    my $output = shift;
    my $debug = 0;
    
    if ( $debug ) {
	print STDERR "[$0] debug mode on - target is: $target_url\n";
    }
    
# list of urls to process
    my @context_urls;
    
# list of requested modes;
    my @modes;
    if ( $mode eq 'full' ) {
	push @modes, 'basic';
	push @modes, 'sentence';
    }
    else {
	push @modes, $mode;
    }

    my $cache = undef;
    if ( -f $context_urls_file && $context_urls_file =~ m/\.url$/ ) {
	
	# open context urls file
        open CONTEXT_URLS_FILE, $context_urls_file or die "unable to open file $context_urls_file: $!";
	
        # read file content
	local $/ = undef;
        my $data = eval(<CONTEXT_URLS_FILE>);
	
	# get memory cache
	$cache = $data->{'context-cache'};

	# get all urls in cache
	@context_urls = keys(%{$cache});

        # close file
        close CONTEXT_URLS_FILE;

    }
    elsif ( -f $context_urls_file ) {
	# open context urls file
	open CONTEXT_URLS_FILE, $context_urls_file or die "unable to open file $context_urls_file: $!";
	
	# read all urls in this file
	@context_urls = map { chomp; $_ } <CONTEXT_URLS_FILE>;
	
	# close file
	close CONTEXT_URLS_FILE;
    }
    elsif ( -d $context_urls_file ) {
	
	if ( $debug ) {
	    print STDERR "loading cache: $context_urls_file ...\n";
	}
	
	$cache = new Cache::FileCache( { 'namespace' => undef, #$target_url, 
					 'default_expires_in' => $Cache::EXPIRES_NEVER,
					 'cache_root' => $context_urls_file } );
	
	# the cache is used both to provide the list of context URLs
	# as well as to provide the content for those URLs
	@context_urls = $cache->get_keys();
	
	if ( $debug ) {
	    foreach my $key (@context_urls) {
		print STDERR "got $key\n";
	    }
	    
	    print STDERR "namespace: " . $cache->get_namespace() . "\n";
	}
	
    }
    else {
	push @context_urls, (split /\s+/, $context_urls_file);
    }
    
# process each url in the context urls file
    my %all_contexts;
    foreach my $context_url (@context_urls) {
	
	if ( $debug ) { print STDERR "[$0] [$context_url] start processing ...\n"; }
	
	# retrieve URL content
	if ( $debug ) { print STDERR "[$0] [$context_url] retrieving content ... "; }
	my $content = get_url_content($context_url, $cache) || '';
	if ( $debug ) { print STDERR "done !\n"; }

	# filter
	if ( $content !~ m/<html/si || $content !~ m/<a/si ) {
	    if ( $debug ) { print "[$0] [$context_url] not HTML, skipping ... "; }
	    next;
	}

	# cleanup content
	if ( $debug ) { print STDERR "[$0] [$context_url] cleaning up content ... "; }
	my $clean_content = cleanse($context_url, $content);
	if ( $debug ) { print STDERR "done !\n"; }

	# mark links
	if ( $debug ) { print STDERR "[$0] [$context_url] marking links ... "; }
	my ($content_with_marked_links, $links_info) = basic_mark_links($target_url, $context_url, $clean_content);
	if ( $debug ) { print STDERR "done !\n"; }

	# build tree
	# if ( $debug ) { print STDERR "[$0] [$context_url] buiding tree ... "; }
	# my $content_tree = $tree_builder->parse($content_with_marked_links);
	# if ( $debug ) { print STDERR "done !\n"; }

	# render
	if ( $debug ) { print STDERR "[$0] [$context_url] rendering HTML content ... "; }
	my $rendered_content_with_marked_links = render($content_with_marked_links);
	# print "content:\n\n$rendered_content_with_marked_links\n\n";
	if ( $debug ) { print STDERR "done !\n"; }

	# find link(s) to target url - this is a configurable process
	if ( $debug ) { print STDERR "[$0] [$context_url] identifying links to target ..."; }
	my @matching_links = find_matching_links($target_url, $links_info);
	if ( $debug ) { print STDERR "done !\n"; }
	
	# independent processing for each mode
	foreach my $mode (@modes) {
	    
	    # mode specific processing
	    my $mode_contexts;
	    if ( $debug ) { print STDERR "[$0] [$context_url] [$mode] extracting context ..."; }
	    if ( $mode eq 'basic' ) {
		$mode_contexts = extract_basic_context($target_url, $rendered_content_with_marked_links, \@matching_links);
	    }
	    elsif ( $mode eq 'sentence' ) {
		$mode_contexts = extract_sentence_context($target_url, $rendered_content_with_marked_links, \@matching_links);
	    }
	    if ( $debug ) { print STDERR "done !\n"; }
	    
	    # store the contexts that have just been generated
	    if ( ! defined $all_contexts{$context_url} ) {
		$all_contexts{$context_url} = ();
	    }
	    if ( ! defined $all_contexts{$context_url}{$mode} ) {
		$all_contexts{$context_url}{$mode} = [];
	    }
	    push @{$all_contexts{$context_url}{$mode}}, map { $mode_contexts->{$_}; } sort { $a <=> $b } keys(%{$mode_contexts});

	}
	
    }

# *****************************************************************************
# output
    
    # Used only for the xml output
    my $tpp = XML::TreePP->new();
    $tpp->set( indent => 2 );
    my $tree = {
	Context => {
	    '-target' => $target_url,
	    'ContextElement' => [],
	}
    };

    # Used only for the line (json) output
    my @anchortext_all;

    foreach my $context_url (keys(%all_contexts)) {

	# my $n0 = scalar(@{$all_contexts{$context_url}->{$modes[0]}});
	# my $n1 = scalar(@{$all_contexts{$context_url}->{$modes[1]}});
	# if ( $n0 != $n1 ) {
	#    warn "we have a problem: $n0 ... $n1\n";
	# }

	# all modes are expected to produce the same number of entries
	for (my $id=0; $id<scalar(@{$all_contexts{$context_url}->{$modes[0]}}); $id++) {

	    my $local_tree = { '-source' => $context_url, '-id' => $id };
	    push @{$tree->{Context}->{ContextElement}}, $local_tree;
	
	    foreach my $mode (keys(%{$all_contexts{$context_url}})) {
	    
		my @local_contexts;
		$local_tree->{$mode} = \@local_contexts;
	    
		my $context = $all_contexts{$context_url}->{$mode}->[$id] || '';

		# clean up
		$context =~ s/\t/ /g;
		$context =~ s/\s+/ /g;
		$context =~ s/^ //g;
		$context =~ s/ $//g;
		
		# Note: this has been creating issues with decode_json downstream
		# semantically this does not make a big difference
		# TODO: better way of escaping backslashes ?
		while ( $context =~ s/\\/\|/sg ) {}

		if ( $output eq 'xml' || $output eq 'line' ) {
			    
		    push @local_contexts, $context;
		    push @anchortext_all, $local_tree;

		}
		else {
		    
		    print "$context_url\t$mode\t$context\n";
			
		}		    		
	    
	    }
	
	}

    }

    if ( $output eq 'xml' ) {
	my $xml = $tpp->write( $tree );
	return $xml;
    }
    elsif ( $output eq 'line' ) {
	my $line = encode_json(\@anchortext_all);
	return $line;
    }

# end of output
# ******************************************************************************************
    
}
    
sub basic_mark_links {

    my $target_url = shift;
    my $context_url = shift;
    my $content = shift;

    my %links_info;
    my $link_count = 0;

    # protect HTML links
    $content =~ s/\n/ /sgi;
    while ( $content =~ s/<a\s+([^>]+)>/$link_marker $link_count /si ) {

	# collect link info
	my $fake_content = "<html><body><a $1>empty</a></body></html>";
	$main::link_extractor->parse($fake_content);
	my @links = $main::link_extractor->links();
	foreach my $link (@links) {
	    my @link_data = @{$link};
	    $links_info{$link_count}{tag} = shift @link_data;
	    while (my $key = shift @link_data) {
		my $value = shift @link_data;
		$links_info{$link_count}{$key} = new URI::URL($value,$context_url);
	    }
	}

	$link_count++;

    }
    $content =~ s/<\/a>/$link_marker/sgi;

    return ($content, \%links_info);

}

sub unmark_links {

    my $text = shift;

    $text =~ s/$link_marker \d+//gsi;
    $text =~ s/$link_marker//gsi;

    return $text;

}

# identify links that point to the target url
sub find_matching_links {

    my $target_url = shift;
    my $links_info = shift;

    my @links;

    foreach my $link_info_id (%{$links_info}) {

        my $link_info = $links_info->{$link_info_id};
	
        my $temp1 = $link_info->{href};
        if ( ! $temp1 ) {
            next;
        }

        my $temp2 = new URI::URL($target_url);

        if ( $main::debug ) {
            print STDERR "comparing: " . $temp1->abs . " and " . $temp2->abs . "\n";
        }

        if ( $temp1->abs eq $temp2->abs ) {

	    if ( $main::debug ) {
                print STDERR "matching: " . $temp1->abs . " and " . $temp2->abs . "\n";
            }

            push @links, $link_info_id;
        }
    }

#       if ( ! @links ) {
#           print STDERR "no link to $target_url found in $url ...\n";
#       }

    return @links;

}

sub extract_basic_context {

    my $target_url = shift;
    my $content_with_marked_links = shift;
    my $matching_links = shift;

    # now process all the links that have been found
    my %contexts;
    foreach my $link_info_id (@{$matching_links}) {

	my $link_text = undef;
	if ( $content_with_marked_links =~ m/$link_marker[[:space:]]$link_info_id[[:space:]](.*?)$link_marker/s) {
	    $link_text = $1;
	    # print "matched: $link_text\n";
	}
	else {
	    # there's a problem
	    # print STDERR "[$0] did not find link \#$link_info_id ...";
	    # exit;
	}

	$contexts{$link_info_id} = $link_text;

    }

    return \%contexts;
    
}

# cleanse HTML content
sub cleanse {

    my $from_url = shift;
    my $content  = shift;

    # replace new-lines with whitespaces
    $content =~ s/\n/ /sg;
    
    # remove extraneaous whitespaces
    $content =~ s/\s+/ /sg;

    return $content;

}

# render HTML content to plain text
sub render {

    my $html_string = shift;

    # create temp file for HTML content
    my ($fh, $filename) = tempfile( TMPDIR => 1 );
    binmode($fh, ':utf8');
    print $fh $html_string;

    # render using lynx
    my $text = `lynx -width=1000000000 -dump -nolist -force_html $filename`; 
    #my $text = $formatter->format_string ($html_string);

    # remove temp file
    unlink($filename);

    return $text;

}

#my $S_BREAK='[\.\?\!\t\n]';
#my $sentence_pattern = qr/$S_BREAK((?:.+)?$link_marker.+?$link_marker.+?$S_BREAK)/o;

sub extract_sentence_context {

    my $target_url = shift;
    my $content_with_marked_links = shift;
    my $matching_links = shift;

    # splits into sentences
    my @sentences;
    # first split into lines
    $content_with_marked_links =~ s/\n+/\n/g;
    my @lines = split /\n/, $content_with_marked_links;
    foreach my $line (@lines) {
	
	if ( ! defined($line) ) {
	    next;
	}

	$line =~ s/^\s+//g;
	$line =~ s/\s+$//g;

	if ( ! $line ) {
	    next;
	}

	my $line_sentences = get_sentences($line);
	if ( ! defined $line_sentences ) {
	    next;
	}
	push @sentences, @{$line_sentences};
    }

    # my @temp_sentences;
    # while ( $content_with_marked_links =~ m/$sentence_pattern/g ) {
    #	push @temp_sentences, $1;
    # }
    # my $sentences = \@temp_sentences;

    # my @temp_sentences = split_sentences( $content_with_marked_links );
    # my $sentences = \@temp_sentences;
    # print STDERR "after splitting ...\n";

    # process all sentences, keeping those that contain one of the matching links
    my %contexts;
    foreach my $link_info_id (@{$matching_links}) {

	my $context_value = undef;
	foreach my $sentence (@sentences) {

	    # clean up sentence
	    $sentence =~ s/\n/ /g;

	    # print "looking for $link_info_id - got sentence: $sentence\n";

	    if ( $sentence !~ m/$link_marker[[:space:]]$link_info_id[[:space:]](.*?)$link_marker/s) {
		next;
	    }
	    
	    # strip out link info
	    $context_value = unmark_links($sentence);

	    # done with this link
	    last;

	}

	if ( $main::debug && ! $context_value ) {
	    die "couldn't find link $link_info_id ...";
	}

	$contexts{$link_info_id} = $context_value;

    }

    return \%contexts;

}

# retrieve URL content, from cache if available
sub get_url_content {

    my $url = shift;
    my $cache = shift;

    my $content = undef;

    if ( $cache ) {
	if ( ref($cache) =~ m/^Cache/ ) {
	    $content = $cache->get($url);
	}
	else {
	    $content = $cache->{$url};
	}
    }

    if ( $content ) {
	return $content;
    }

    my $response = undef;
    eval {
        $response = $main::mech->get( $url );
    };

    if ( !$main::mech->success() ) {
        if ( $main::debug ) {
            print STDERR "failed to download $url\n";
	    $content = "__DOWNLOAD_FAILURE__";
        }
    }
    else {
	$content = $response->decoded_content;
    }

    my $MAX_CONTENT_SIZE = 500000;
    if ( defined( $content ) && length($content) > $MAX_CONTENT_SIZE ) {
        $content = "__TOO_LARGE__";
    }

    # make sure we have utf-8 content ?
#    if ( ! utf8::is_utf8( $content ) ) {
#	print STDERR "Problem: fetched data for URL $url is not properly UTF-8 encoded ...\n";
#	$content = Encode::encode_utf8( $content );
#    }

    # clean-up --> tidy ?
    # $cleaned_up_context = $response->decoded_content;
    # my $cleaned_up_content = $content;

    return $content;

}


__END__

=pod

=head1 NAME
    
    sample - Using Getopt::Long and Pod::Usage
    
=head1 SYNOPSIS
    
    sample [options] TARGET_URL SOURCE_URL|SOURCE_URLS_FILE|SOURCE_URLS_CACHE

    Options:
       -help            brief help message
       -man             full documentation
       -mode            context extraction mode

=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>

    Prints the manual page and exits.

=back

=head1 DESCRIPTION

    B<This program> will read the given input file(s) and do something
    useful with the contents thereof.

=cut

