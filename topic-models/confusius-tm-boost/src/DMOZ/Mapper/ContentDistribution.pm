package DMOZ::Mapper::ContentDistribution;

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use VectorContentDistribution;
# use Tokenizer;

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

}

# pre-processing method
sub pre_process {
	
    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;
        
}

# post-processing method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;
    my $recursion_data = shift;

    my $content_distribution = undef;

    if ( $node->type() eq 'entry' ) {
    
=pod
	# tokenize this entry's description
	my $tokens = Tokenizer->tokenize($node->{description});
    
	# store tokens for this entry's description
	$node->set('description-tokens', $tokens);
    
	# remove tokens that are not part of the vocabulary
	my @vocabulary_tokens = grep { defined($this->{_vocabulary}->word_index($_)); } @$tokens;
=cut

	my @vocabulary_tokens = split /\s+/, $node->{description};
    
	# produce content distribution for this entry
	$content_distribution = VectorContentDistribution::generateFromTokens(\@vocabulary_tokens, $this->{_vocabulary});

    }
    else {
    
	# combine the content distributions of the children nodes
	my $aggregate_model = undef;
	
	my @submodels = grep { $_; } @$recursion_data;
	
	if ( scalar(@submodels) ) {
	
	    $aggregate_model = shift @submodels;

	    map { $aggregate_model = VectorContentDistribution::merge_distributions($aggregate_model, $_); } @submodels;
	    
	    $content_distribution = $aggregate_model;

	}
	else {
	    
	    $content_distribution = VectorContentDistribution::generateFromTokens([], $this->{_vocabulary});

	}

    }

    # save content distribution
    $node->set('content-distribution', $content_distribution);

    return $content_distribution;

}

1;

