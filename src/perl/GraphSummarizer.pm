package GraphSummarizer;

use strict;
use warnings;

use HTML::TokeParser;
use HTML::TreeBuilder;
use JSON;
use Text::Trim;

use utf8;

# chunkify HTML content
sub _chunkify_content {

    my $raw_content = shift;
    my $chunks = shift;

    # TODO: should this logic (how to transform a modality prior to its tokenization) be configurable ? 
    my $chunkified_content = undef;
    if ( ! ref( $chunkified_content ) ) {
	$chunkified_content = $raw_content;
    }
    else {
	$chunkified_content = join( " " , @{ $raw_content } );
    }

    # tidy up content - just in case
    # $chunkified_content = HTML::Tidy::tidy( $chunkified_content );

    my $p = HTML::TokeParser->new( \$chunkified_content , ignore_elements => [qw(script style)] ) || die "Unable to parse raw HTML: $!";
    $p->empty_element_tags(1);  # configure its behaviour
    
    my @stream;
    my @stream_context;
    my %matching;
    my %matching_context;

    my $empty_context = "";
    my $in_script = 0;
    my @context;

    # prepare regexes
    my %nodeid2re;
    my %nodeid2replacement;
    if ( defined( $chunks ) ) {

	foreach my $chunk (@{$chunks}) {
	
	    if ( $chunk->{type} ne 'np' ) {
		next;
	    }

	    my $chunk_id = $chunk->id();
	    my $chunk_matcher = $chunk->chunk_matcher();
	    my $replacement_string = $chunk->placeholder();
	    
	    $nodeid2re{ $chunk_id } = $chunk_matcher;
	    $nodeid2replacement{ $chunk_id } = " $replacement_string ";

	}

    }

    while (my $token = $p->get_token) {

	my $type = $token->[0];
	my $tag = $token->[1];
	my $value = $token->[2];

	if ( $tag eq 'script' ) {

	    if ( $type eq 'S' ) {
		$in_script++; 
	    }
	    else {
		$in_script--;
	    }

	    next;

	}

	if ( $in_script ) { next; }

	my $fragment = undef;
	if ( $type eq 'S' ) {
	    $fragment = join("", "<", $tag, ">");
	    push @context, $tag;
	    next;
	}
	elsif ( $type eq 'E' ) {
	    $fragment = join("", "</", $tag, ">"); 
	    pop @context;
	    next;
	}

	# should rename those variables :-P
	my $cleansed_text = $tag;
	if ( defined($cleansed_text) ) { 
	    $cleansed_text =~ s/\s+/ /g;
	    trim($cleansed_text);
	    $fragment = _render_html("<html><body>$cleansed_text</body></html>");
	    #$fragment = $cleansed_text;
	}
	
	if ( defined($fragment) && length($fragment) ) {
	 
	    
	    foreach my $nodeid (keys( %nodeid2re )) {
		
		my $re = $nodeid2re{ $nodeid };
		my $replacement = $nodeid2replacement{ $nodeid };
		
		if ( $fragment =~ s/$re/$replacement/ig ) {
		    # print STDERR "match for $chunk_matcher ($chunk_id) --> $token --> $replacement_string\n";
		    $matching{ $nodeid }++;
		    $matching_context{ join("::", scalar(@context)?$context[$#context]:"", $nodeid) }++;
		}
		
	    }
	    
	    # allow partial match ?
	    # for now proceed with exact match, will look into partial match if we end up missing out on the extraction of too many
	    # target-specific NPs

	    push @stream, $fragment;
	    push @stream_context, scalar(@context)?$context[$#context]:$empty_context;

	}
	
    }

    # TODO: can we remove this eventually ?
    # in case this was not HTML content
    if ( scalar(@stream) == 1 ) {
	@stream = split /\s+/, $chunkified_content;
	@stream_context = ( $empty_context );
    }

    return (\@stream, \@stream_context, \%matching, \%matching_context);

}

sub _render_html {

    my $html_string = shift;

    my $text = "";
    
    eval {
        my $tree = HTML::TreeBuilder->new; # empty tree
        $tree->utf8_mode(0);
        my $p = $tree->parse($html_string);
        $text = $p->as_trimmed_text;
        #$p->delete;
        $tree = $tree->delete;
    };

    return $text;

}

# fine grain tokenization of content (assumes chunks/phrases have been properly abstracted out)
sub _chunk_tokenize_content {

    my $mapped_content_stream = shift;

    my @tokenized_content;

    foreach my $content_element (@$mapped_content_stream) {

	if ( $content_element !~ m/^\</ ) {

	    my @tokens = split /\s+/, $content_element;
	    push @tokenized_content, @tokens;

	}
	else {
	    push @tokenized_content, $content_element;
	}

    }

    return \@tokenized_content;

}

1;
