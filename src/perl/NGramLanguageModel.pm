package NGramLanguageModel;

# implementation for all (1/2/3/...) n-gram language models
# this is a wrapper around the SRILM toolkit, with additional
# assumptions regarding the token space

# unless otherwise specified (flag ?) numerical tokens are treated
# as token ids. Since SRILM reserves ids 0-3 for special tokens
# (OOV,<s>,</s>,<art>) all token ids are shifted by 4.

use strict;
use warnings;

# TODO : create shared resource for distribution paths ?
use Module::Path qw/module_path/;
use Path::Class;
# TODO : limit redundant code with PathCostLPLearner
my $lm_bin = join( "/" , file( module_path(__PACKAGE__) )->parent() , "../../third-party/local/bin/" );

use File::Temp qw/ tempfile /; #:seekable ??
use List::MoreUtils qw/ uniq /;
use Proc::Simple;

use LanguageModel;
use base('LanguageModel');

# are all incoming tokens expected to be token ids (except for special tokens) ?
my $use_token_ids = 1;
my $srilm_offset = 3;

# options for SRILM
my $common_srilm_options_1 = "-no-sos -no-eos -unk";
my $common_srilm_options_n = "-unk";

# debug level for SRILM
#my $srilm_debug_level = 0;
my $srilm_debug_level = 2;

my @cues = ("<s>", "<p>", "<art>");

# constructor
sub new {

    my $that = shift;
    my $n = shift;
    my $vocabulary = shift;

    my $class = ref($that) || $that;

    # obj ref
    my $ref = $that->SUPER::new();

    # store window size
    $ref->{_n} = $n;

    # total number of documents/updated (do we need this ?)
    $ref->{_n_docs} = 0;

    # total number of ngrams
    $ref->{_n_total} = {};

    # n-gram counts
    $ref->{_n_grams} = {};

    # vocab
    $ref->{_vocab} = {};

    # the actual language model
    $ref->{_lm} = undef;
    $ref->{_lm_file} = undef;

    # if this lm is available through a server process, what port number is it on ?
    $ref->{_server_process} = undef;
    $ref->{_server_process_status} = undef;
    $ref->{_port} = undef;

    # temp file to hold the input data
    # TODO: move this to language model builder
    $ref->{_tmp_input} = File::Temp->new( UNLINK => 1 , SUFFIX => '.txt' );

    for (my $i=1; $i<=$ref->{_n}; $i++) {
	$ref->{_n_total}->{$i} = 0;
	$ref->{_n_grams}->{$i} = {};
	$ref->{_n_tokens}->{$i} = [];
    }

    return $ref;

}

# load data using a server process
# returns a language model object, with port number set
sub loadServer {

    my $that = shift;
    my $model_data = shift;
    my $order = shift;

    # instantiate language model object
    my $language_model = new NGramLanguageModel($order);
    my $options = '';

    # get new port number (make sure it's available)
    my $port_number = 10000 + $order;

    # actually start the server process
    my ($myproc, $tmp_status_check) = $that->startServer($order, $model_data, $options, $port_number);

    # store the server process information
    $language_model->{_server_process} = $myproc;
    $language_model->{_server_process_status} = $tmp_status_check;

    # store port number
    $language_model->port($port_number);

    # return
    return $language_model;

}

sub startServer {

    my $that = shift;
    my $size = shift;
    my $model_file = shift;
    my $options = shift;
    my $port_number = shift;

    # start up server using this language model
    my $myproc = Proc::Simple->new();
    my $tmp_status_check = File::Temp->new( UNLINK => 1 , SUFFIX => '.lm.server.status' );
    my $ngram_command = "$lm_bin/ngram -lm $model_file -order $size -debug $srilm_debug_level $options -server-port $port_number 2> $tmp_status_check";
    print STDERR "[__PACKAGE__] starting lm server using: $ngram_command\n";
    $myproc->start($ngram_command);
    
    # wait for the server to properly start up
    while(1) {
	
	my $on = 0;
	
	{
	    local $/ = undef;
	    open STATUS_FILE, $tmp_status_check or die "unable to open status check for language model server ...";
	    my $status_content = <STATUS_FILE>;
	    if ( $status_content =~ m/starting prob server on port $port_number/s ) {
		$on = 1;
	    }
	    close STATUS_FILE;
	}
	
	if ( $on ) {
	    last;
	}
	
	sleep(5);
	
    }
    
    $myproc->kill_on_destroy(1);
    
    return ($myproc, $tmp_status_check);
    
}

# set/get the port number for this language model
sub port {

    my $this = shift;
    my $port_number = shift;

    if ( defined($port_number) ) {
	$this->{_port} = $port_number;
    }

    return $this->{_port};

}

# return the perplexity of the model wrt sequence of tokens
sub perplexity {

    my $this = shift;
    my $size = shift;
    my $tokens = shift;

    my $perplexity = undef;

    my $output = $this->_perplexity_command($size, $tokens);

    if ( $output ) {
	$perplexity = $output->{perplexity_1};
    }

    return $perplexity;

}

=pod
# returns the perplexity for the content of the speficied file
sub perplexityFromFile {

    my $this = shift;
    my $file_name = shift;

    my $perplexity = undef;

    open INPUT_FILE, $file_name or die "Unable to open input file $file_name: $!";
    {
	my @lines = map { chomp; \ split / /, $_; } <INPUT_FILE>;
	$perplexity = $this->perplexity(@lines);
    }
    close INPUT_FILE;

    return $perplexity;

}
=cut

# return the probability of a particular sequence of tokens
sub probability {

    my $this = shift;
    my $size = shift;
    my $tokens = shift;

    # map tokens as needed
    my @updated_tokens = @{ $this->map_tokens($tokens) };

    my $probability = undef;

    my $perplexity_data = $this->_perplexity_command($size, \@updated_tokens);

    if ( ! defined($perplexity_data) ) {
	print STDERR "[__PACKAGE__] perplexity for tokens (" . join("-", @updated_tokens) . ") is undefined\n";
    }
    else {
	#$probability = 10 ** (-1 * _ln($perplexity) * ( scalar(@updated_tokens) + 1 ) / _ln(10));

	$probability = 10 ** $perplexity_data->{logprob};

	# ppl = 10 ** (-1 * logprob / ( # sent + # word ) )
	#$probability = 10 ** ( -1 * log ( $perplexity ) * (scalar(@updated_tokens) + 1))
    }

    return $probability;

}

# map tokens from application token space to SRILM token space
sub map_tokens {

    my $this = shift;
    my $original_tokens = shift;

    my @mapped_tokens;

    if ( $use_token_ids ) {
	@mapped_tokens = map { if ( $_ =~ m/^\d+$/ ) { $_ + $srilm_offset; } else { $_ } } @$original_tokens;
    }
    elsif ( $this->{requires_token_mapping} ) {
	@mapped_tokens = @{ $this->normalize_oov_tokens($original_tokens) };
    }
    else {
	@mapped_tokens = @$original_tokens;
    }

    return \@mapped_tokens;

}

# compute natural logarithm
sub _ln {

    my $x = shift;
    return ( log($x) / log(exp(1)));

}

# underlying command
sub _perplexity_command {

    my $this = shift;
    my $size = shift;
    my $tokens = shift;

    my $model_file = $this->{_lm_file};

    my @updated_tokens = @{ $this->map_tokens($tokens) };

    # prepare temp input
    my $tmp_input = File::Temp->new( UNLINK => 1 , SUFFIX => '.tmp' );
    print $tmp_input $this->prepare_lm_string($size, \@updated_tokens) . "\n";

    # compute perplexity
    my $options = $this->get_lm_options($size);

    my $lm_parameters = undef;
    if ( defined($this->port) ) {
	my $port_number = $this->port;
	$lm_parameters = "-use-server ${port_number} -cache-served-ngrams"
    }
    else {
	$lm_parameters = "-lm $model_file"
    }

    my @output = map { chomp; $_; } `$lm_bin/ngram $lm_parameters -order $size -debug $srilm_debug_level -ppl $tmp_input $options`;

    # parse output
    my $structure = {};
    my $found_file_stats = 0;
    my $found_results = 0;
    my $extra_info_count = 0;
    foreach my $output_line (@output) {

	$extra_info_count++;

	# parse output
	if ( $output_line =~ m/file (.+): (\d+) sentences?\, (\d+) words?\, (\d+) OOVs?/ ) {
	    $structure->{file} = $1;
	    $structure->{n_sentences} = $2;
	    $structure->{n_words} = $3;
	    $structure->{n_oovs} = $4;

	    $found_file_stats = 1;
	}
	
	# ppl --> includes sentence count in calculation
	# ppl1 --> does not include sentence count in calculation
	if ( $output_line =~ m/(\d+) zeroprobs?\, logprob= ([^ ]+) ppl= ([^ ]+) ppl1= ([^ ]+)/ ) {
	    $structure->{zeroprobs} = $1;
	    $structure->{logprob} = $2;
	    $structure->{perplexity} = $3;
	    $structure->{perplexity_1} = $4;

	    $found_results = 1;
	}


	if ( $found_file_stats || $found_results ) {
	    next;
	}

	print STDERR "extra info: $output_line\n"; 

    }

    if ( !$found_file_stats || !$found_results ) {
	print STDERR "invalid output from SRILM with $extra_info_count lines ...\n";
	return undef;
    }

    return $structure;

}

# add a sequence of tokens to this model (update stats)
sub update {

    my $this = shift;
    my $tokens = shift;

    # update vocab
    my @updated_tokens = @{ $this->map_tokens($tokens) };
    map { if ( defined($_) ) { $this->{_vocab}->{$_}++; } } @updated_tokens;

    # update temp input file
    my $tmp_input = $this->{_tmp_input};
    print $tmp_input $this->prepare_lm_string($this->{_n}, \@updated_tokens, 1) . "\n";

    # update stats
    $this->{_n_docs}++;

}

# build the n-gram language model
# currently this is a wrapper for the CMU Language Toolkit
sub build {

    my $this = shift;
 
    my $size = $this->{_n};
    
    # generate context cues file
    my $tmp_context = File::Temp->new( UNLINK => 1 , SUFFIX => '.ccs' );
    print $tmp_context join("\n", @cues);

    # using SRILM
    my $tmp_input = $this->{_tmp_input};
    print STDERR "input size: " . `wc -l $tmp_input` . "\n";

    my $options = $this->get_lm_options($size);

    # generate language model
    print STDERR "[begin lm generation] ***********************\n"; 
    my $tmp_lm = File::Temp->new( UNLINK => 1 , SUFFIX => '.lm' );
    my $success3 = `$lm_bin/ngram-count -text $tmp_input -order $size $options -lm $tmp_lm`;
    print STDERR "[end lm generation] ***********************\n\n";

    $this->{_lm} = $tmp_lm;

}

# serialize to the specified file
sub serialize {

    my $this = shift;
    my $target_dir = shift;

    # simply copy lm file to target file
    my $source_file = $this->{_lm};
    my $target_file = join("/", ($target_dir, "lm"));
    `cp $source_file $target_file`;

    # we no longer need the lm file
    delete $this->{_lm};

    # we no longer need the tmp input file
    delete $this->{_tmp_input};

    # serialize object to file
    my $target_object_file = join("/", ($target_dir, "object"));
    return $this->SUPER::serialize($target_object_file);

}

# instantiate from the specified file
sub deserialize {

    my $that = shift;
    my $source_dir = shift;

    # deserialize object from file
    my $source_object_file = join("/", ($source_dir, "object"));
    my $lm = $that->SUPER::deserialize($source_object_file);

    if ( ! $lm ) {
	return undef;
    }

    # load lm file
    $lm->{_lm_file} = join("/", ($source_dir, "lm"));

    return $lm;

}

# prepare lm string
sub prepare_lm_string {

    my $this = shift;
    my $size = shift;
    my $tokens = shift;
    my $include_sentence_markers = shift || 0;

    my $lm_string = join(' ', @$tokens);
    if ( $include_sentence_markers ) {
	$lm_string = join(' ', '<s>', $lm_string, '</s>');
    }

    return $lm_string;

}

# get lm options
sub get_lm_options {

    my $this = shift;
    my $size = shift;

    # should always be good
    return $common_srilm_options_1;

    my $options = undef;
    if ( $size == 1 ) {
# makes absolutely no difference during perplexity computation (testing)
# the set options is set after training ...
	$options = $common_srilm_options_1;
#	$options = $common_srilm_options_n;
    }
    else {
	$options = $common_srilm_options_n;
    }

    return $options;

}

1;
