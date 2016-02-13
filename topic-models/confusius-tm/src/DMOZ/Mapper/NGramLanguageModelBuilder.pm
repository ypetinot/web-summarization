package DMOZ::Mapper::NGramLanguageModelBuilder;

# build an n-gram language model by recursing over the DMOZ entries

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use NGramLanguageModel;
use Tokenizer;
use Vocabulary;

# constructor
sub new {

    my $that = shift;
    my @sizes = @_;

    # instantiate super class
    my $ref = $that->SUPER::new();

    # store requested sizes
    $ref->{_ngrams} = {};
    map { $ref->{_ngrams}->{$_} = undef } @sizes;

    return $ref;

}

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    # instantiate vocabulary object
    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

    # instantiate one n-gram model per requested size
    foreach my $size (keys %{ $this->{_ngrams} }) {
	$this->{_ngrams}->{$size} = new NGramLanguageModel($size);
    }

    $this->{_data} = [];

}

# processing method
# TODO: need to be able to specify which field we want to create the language model for
sub process {

    my $this = shift;
    my $node = shift;

    # get tokens for this entry
    my $tokens = Tokenizer->tokenize($node->{description});

    # map tokens to their ids
    my $token_count = 0;
    my @token_ids = map {
	$token_count++;
	my $original_token = $_;
	my $token_id = $this->{_vocabulary}->word_index($original_token);
	if ( !defined($token_id) ) {
	    print STDERR "warning, token $original_token is OOV ! ($token_count)\n";
	}
	$token_id;
    } @$tokens;

    # update n-gram language models for this node
    foreach my $ngram_model (values %{ $this->{_ngrams} }) {
	$ngram_model->update(\@token_ids);
    }
  
}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;

    # finalize the n-gram models    
    foreach my $size (keys %{ $this->{_ngrams} }) {

	my $ngram_model = $this->{_ngrams}->{$size};

	# build language model
	$ngram_model->build();

	# create permanent storage location
	my $target_directory = $hierarchy->getPropertyDirectory('ngrams',$size);

	# store language model
	$ngram_model->serialize($target_directory);

    }

}

1;

