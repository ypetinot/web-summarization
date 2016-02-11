package Web::Summarizer::OcelotSummarizer;

# (base class for all) ocelot summarizer

use strict;
use warnings;

use NGramLanguageModel;
use Vocabulary;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use FindBin;
use Getopt::Long;
use IPC::Open3;
use JSON;
use Pod::Usage;
use URI;
use URI::URL;
use File::Path;
use File::Temp qw/tempfile/;
use Module::Path qw/module_path/;
use Path::Class;
use Text::Trim;

use Moose;
use namespace::autoclean;

with('Web::Summarizer');

my $DEBUG = 1;

# id
has 'id' => ( is => 'ro' , isa => 'Str' , default => "ocelot" );

# manages the execution of the OCELOT #3 summarizer

# mode : 1 / 2 / 3
# TODO ?

# translation model base
has 'translation_model_base' => ( is => 'ro' , isa => 'Str' , required => 1 );

# translation model file
has 'translation_model_file' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_translation_model_file_builder' );
sub _translation_model_file_builder {
    my $this = shift;
    $this->ocelot_model_file( 'dic.ti.final' );
}

# source vocabulary file
has '_tm_source_vocabulary_file' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_source_vocabulary_file_builder' );
sub _source_vocabulary_file_builder {
    my $this = shift;
    return $this->ocelot_model_file( 'dic.trn.src.vcb' );
}

# source vocabulary
has 'source_vocabulary' => ( is => 'ro' , isa => 'Vocabulary' , init_arg => undef , lazy => 1 , builder => '_source_vocabulary_builder' );
sub _source_vocabulary_builder {
    my $this = shift;
    return Vocabulary->load( $this->ocelot_model_file( 'dmoz.ocelot.source.vocabulary' ) );
}

# output vocabulary file
has '_tm_output_vocabulary_file' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_output_vocabulary_file_builder' );
sub _output_vocabulary_file_builder {
    my $this = shift;
    return $this->ocelot_model_file( 'dic.trn.trg.vcb' );
}

# output vocabulary
has 'output_vocabulary' => ( is => 'ro' , isa => 'Vocabulary' , init_arg => undef , lazy => 1 , builder => '_output_vocabulary_builder' );
sub _output_vocabulary_builder {
    my $this = shift;
    return Vocabulary->load( $this->ocelot_model_file( 'dmoz.ocelot.output.vocabulary' ) );
}

# lm order
has 'ngram_order' => ( is => 'ro' , isa => 'Num' , default => 3 );

our $LM_DEBUG_LEVEL=3;

# lm server port
has 'ngram_server_port_number' => ( is => 'ro' , isa => 'Num' , default => 5010 );

our $LM_OPTIONS='';

# lm model file
has 'ngram_model_file' => ( is => 'ro' , isa => 'Str' , required => 1 );

# Note : LM server is to be started separately (can we make this a service ?)
=pod
# lm server
# TODO : can I use a type constraint that's more specific ?
has 'ngram_server' => ( is => 'ro' , isa => 'Ref' , init_arg => undef , lazy => 1 , builder => '_lm_server_builder' );
sub _lm_server_builder {
    my $this = shift;
    my ($proc_obj, $status_file) = NGramLanguageModel->startServer( $this->ngram_order , $this->ngram_model_file , $LM_OPTIONS , $this->ngram_server_port_number );
    return $proc_obj;
}
=cut

# ocelot bin dir
has 'ocelot_bin_dir' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_ocelot_bin_dir' );
sub _ocelot_bin_dir {
    my $this = shift;
    # TODO : limit redundant code with PathCostLPLearner
    # TODO : is there a more standard way of getting this path ?
    my $ocelot_bin_dir = join( "/" , file( module_path(__PACKAGE__) )->parent() , "../../" );
    return $ocelot_bin_dir;
}

sub ocelot_model_file {
    my $this = shift;
    my $filename = shift;
    return join( "/" , $this->translation_model_base , $filename );
}

sub start_lm_server {

    my $this = shift;
   
    # TODO : might need to improve this at some point
    #$this->ngram_server;

    # Note : server to be started separately and prior to calling this class
    # TODO : can we do better ? can this class control the ngram server ?

    # TODO : server host should become a parameter
    my $lm_server_location = $this->ngram_server_port_number . '@barracuda.cs.columbia.edu';

    return $lm_server_location;

}

sub summarize {
    
    my $this = shift;
    my $instance = shift;

    # starts up LM server
    # TODO : the server should be decoupled from this script (or possibly auto-terminate after a period of inactivity ?)
    $this->info("Starting Language Model server ...");
    my $server_info = $this->start_lm_server;

    # launch ocelot #3 decoder
    my $dist_bin_dir = $FindBin::Bin;
    my $ocelot_bin_dir = $this->ocelot_bin_dir;
    my $tm_output_vocabulary_file = $this->_tm_output_vocabulary_file;
    my $tm_source_vocabulary_file = $this->_tm_source_vocabulary_file;
    my $translation_model_file = $this->translation_model_file;

    my $ocelot_bin = "${ocelot_bin_dir}/ocelot-3";
    my $ocelot_command = "${ocelot_bin} --lm-server-info=${server_info} --tm-file=${translation_model_file} --source-vocabulary=${tm_source_vocabulary_file} --output-vocabulary=${tm_output_vocabulary_file} | stdbuf -o0 awk -F\"\\t\" '{ print \$2 }'";
###| stdbuf -o0 ${dist_bin_dir}/dmoz-map-vocabulary --reverse --vocabulary=${source_vocabulary_file}";
    print STDERR "[ocelot] starting ocelot backend : $ocelot_command\n";
    my $ocelot_command_debug = "gdb ${ocelot_bin}";
    $this->info( "Ocelot command : $ocelot_command" );

    my $input_content = $instance->get_field( 'content.rendered' );
    my $oov_id = $this->output_vocabulary->word_index( 'OOV' );
    my $input_content_mapped = $this->output_vocabulary->map_to_ids( $input_content , $oov_id );

    # TODO : use service instead ?

    my $pid;
    
###    # TODO : is there a way to better integrate the debug mode ?
###    if ( $DEBUG ) {
###	#$pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, $ocelot_command_debug ) or die "open3() failed $!";
###	system( "echo ${input_content} | ${ocelot_command_debug}" );
###    }
###    else {

    $pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, $ocelot_command ) or die "open3() failed $!";
    # TODO : make this a debug log entry
    $this->info("mapped input content: $input_content_mapped");

    # create temp file
    my $input_file = new File::Temp;
    print STDERR "[ocelot] writing mapped input to : $input_file\n";
    print $input_file "$input_content_mapped\n";
    print STDERR `cat $input_file` . "\n";
    print CHLD_IN "$input_content_mapped\n";
    
    # TODO : I need to find a way of avoiding this
    close CHLD_IN;

###    }

    my $summary_unmapped  = <CHLD_OUT>;
    my $summary = $this->source_vocabulary->map_to_words( $summary_unmapped );

    $this->debug("Ocelot raw summary : $summary");

    # turn summary into an object
    my $summary_object = $this->sentence_builder->build( $summary , $instance );

    return $summary_object;

}

__PACKAGE__->meta->make_immutable;

1;
