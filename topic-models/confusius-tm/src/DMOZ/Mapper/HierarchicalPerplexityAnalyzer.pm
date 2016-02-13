package DMOZ::Mapper::HierarchicalPerplexityAnalyzer;

# computes perplexity of a set of DMOZ entries wrt specified model

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use DMOZ::HierarchicalLanguageModel;
use Vocabulary;

# constructor
sub new {

    my $that = shift;
    my $model_type = shift;

    # instantiate super class
    my $ref = $that->SUPER::new();

    $ref->{_model_type} = "hierarchical";

    return $ref;

}

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_hierarchy} = $hierarchy;

    # instantiate vocabulary object
    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

    $this->{_language_model} = new DMOZ::HierarchicalLanguageModel($hierarchy);

    $this->{_current_perplexity_sum} = 0;
    $this->{_current_count} = 0;

}

# pre process method
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    my $sibling_threshold = 0;

    my $word_assignment = $node->get('word-assignment');
    my $content_distribution = $node->get('content-distribution');
    
    if ( $node->type() eq 'category' ) {
	return [ $word_assignment , $content_distribution , $node->name() ];
    }

    my $depth = scalar(@$path);

    # get sequence of tokens for this node
    my @tokens = @{ $node->get('description-tokens') };

    # map tokens to their ids 
    my @token_ids = map { $this->{_vocabulary}->word_index($_) } @tokens;   
	
    # get language model perplexity for this sequence of tokens
    my $sequence_perplexity = $this->{_language_model}->perplexity(\@token_ids, $data);
	
    # store perplexity info
    $node->set_hash('perplexity', 'hierarchical-perplexity', $sequence_perplexity);

    # update aggregate variables
    $this->{_current_perplexity_sum} += $sequence_perplexity;
    $this->{_current_count}++;

    return undef;
    
}

# post process method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;
    my $recursion_outputs = shift;

    # nothing

}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;
	
    my $perplexity = 0;
    if ( $this->{_current_count} ) {
	$perplexity = $this->{_current_perplexity_sum} / $this->{_current_count};
    }

    print STDERR "[" . $this->{_model_type} . "] perplexity: $perplexity\n";

}

1;

