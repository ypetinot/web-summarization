package DMOZ::Mapper::CategoryBasedSummarizer;

use strict;
use warnings;

# this summarizer uses all the sibling entries in a category to produce the
# best possible summary for a target URL.

# strategy 1: strip out all words that are specific to the siblings and not
# supported by the target. Select the resulting summary that is most central
# (e.g. highest average pairwise similarity).

# TODO: for this type of summarizer, the number of entries in a category is important
# we want to split the data as follows: 98% training, 1% testing, 1% held-out

# TODO: summarizer should proceed at a level where we have a sufficient number of sibling summaries

use VectorContentDistribution;
use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use String::Similarity;

binmode(STDOUT, ":utf8");

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_vocabulary} = $hierarchy->getCategoryNode("Top")->get('vocabulary');

}

# pre process method
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    my $sibling_threshold = 0;

    if ( $node->type() eq 'category' ) {

	push @$data, $node->get('word-assignment');
	return;

    }
    
    # get parent category based on the number of documents found under that category
    $sibling_threshold = 20;
    my $depth = scalar(@$path) - 1;
    while ( $depth ) {

	my $current_category = $path->[$depth];
	my $current_category_content_distribution = $current_category->get('content-distribution');

	# TODO: make the number of documents under node a default property of category nodes
	my $number_of_documents_under_category = $current_category_content_distribution->number_of_documents();

	if ( $number_of_documents_under_category < $sibling_threshold ) {
	    $depth--;
	}
	else {
	    # we have enough documents to proceed
	    last;
	}
     
    }

    return $this->summarize($node,$path,$data,$depth);

}

# post process method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    if ( $node->type() eq 'category' ) {
	pop @$data;
    }

    # nothing

}

# which node in the current path generated this word ?
sub _get_word_origin {

    my $this = shift;
    my $path_data = shift;
    my $word = shift;

    my $depth = scalar(@$path_data);

    my $i;
    for ($i=0; $i<$depth; $i++) {
	if ( $path_data->[$i]->{$word} ) {
	    return $i;
	}
    }

    return $i;

}

# summarization method
# inputs:
# --> $target_node: the node for which we want to generate a summary (do we need to generate a node really ?)
# --> $location_node: the (category node) where the target node is placed for summary generation
sub summarize {

    my $this = shift;
    my $target_node = shift;
    my $path = shift;
    my $data = shift;
    my $target_depth = shift;

    my $location_node = $path->[$target_depth];

    my $summary = '';

    # get target URL
    my $url = $target_node->{url};

    # get current depth
    my $depth = scalar(@$path);

    # get content distribution (content)
    my $content_distribution = VectorContentDistribution::generateFromContent(
	$target_node->get('content') || '',
	'html',
	$this->{_vocabulary}
	);
    
    # get model summary
    my $model_summary = $target_node->{description};
    
    # get sibling nodes
    my @siblings = grep { $_->type() eq 'entry' && $_->get('label') eq 'training' } $location_node->getDescendants(
	sub { my $node = shift; if ( ($node->type() eq 'entry') && ($node->get('label') eq 'training') ) { return 1; } return 0; } );

    my @candidate_summaries;
    foreach my $sibling (@siblings) {
	
	# any better way of checking for equality ?
	if ( $sibling->name eq $target_node->name ) {
	    next;
	}
	
	my $sibling_desc_content_distribution = $sibling->get('content-distribution');
	my $sibling_tokens = $sibling->get('description-tokens');
	my @abstracted_tokens;
	my $has_hard_token = 0;
	my $n_tokens = scalar(@{$sibling_tokens});
	foreach my $sibling_token (@{$sibling_tokens}) {
	    
	    my $keep = 0;
	    
	    my $sibling_token_id = $this->{_vocabulary}->word_index($sibling_token);

	    # is this a generic token ?
	    my $word_origin = $this->_get_word_origin($data, $sibling_token);
	    if ( defined($word_origin) && ($word_origin <= $depth) ) {
		$keep = 1;
	    }
	    # is this a token that appears in the target document ?
	    elsif ( defined($sibling_token_id) && $content_distribution->tf($sibling_token_id) ) {
		$keep = 1;
	    }
	    
	    my $token = undef;
	    if ( $keep ) {
		$token = $sibling_token;
		$has_hard_token++;
	    }
	    else {
		my $token_pos = $this->{_vocabulary}->get_pos($token);
		$token = "[[ SLOT::$token_pos ]]";
	    }
	    
	    push @abstracted_tokens, $token;
	    
	}
	
	#if ( $has_hard_token / $n_tokens > 0.5 ) {
	    push @candidate_summaries, join(' ', @abstracted_tokens);
	#}
	
    }
    
    # rank candidates based on average pairwise similarity
    my %candidate2similarity;
    for (my $i=0; $i<scalar(@candidate_summaries); $i++) {
	
	my $similarity_temp;
	
	for (my $j=0; $j<scalar(@candidate_summaries); $j++) {
	    
	    if ( $i == $j ) {
		next;
	    }
	    
	    $similarity_temp += similarity($candidate_summaries[$i], $candidate_summaries[$j]);
	    
	}
	
	$candidate2similarity{$candidate_summaries[$i]} = $similarity_temp;
	
    }
    
    my @sorted_candidates = sort { $candidate2similarity{$b} <=> $candidate2similarity{$a} } keys(%candidate2similarity);
    
    if ( scalar(@sorted_candidates) ) {
	$summary = $sorted_candidates[0];
    }
    else { # if there is no candidate summary, we default to a regular content-based summary
	$summary = "__DEFAULT_SUMMARY__";
    }

    print join("\t", ($location_node->name(), scalar(@siblings), $url, $summary, $model_summary)) . "\n";
    

}

1;

