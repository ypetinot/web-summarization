package Web::Summarizer;

# base class for all summarizers

use strict;
use warnings;

use Web::Summarizer::SentenceBuilder;
use Web::Summarizer::State;

use File::Path;

use Moose::Role;
###use namespace::autoclean;
use MooseX::ClassAttribute;
with('MooseX::Getopt::Dashes');
# TODO: currently does not install
##    'MooseX::Getopt::Usage',
##    'MooseX::Getopt::Usage::Role::Man';

with('Logger');

# system id
has 'system' => ( is => 'ro' , isa => 'Str' , required => 1 );

# TODO : to be removed ?
=pod
# TODO : does this make sense as a generic attribute for all Web::Summarizer's ? => seems so, currently this is used by TitleSummarizer and ReferenceTargetSummarizer
# TODO : really ok to have this has a class attribute ?
class_has 'sentence_builder' => ( is => 'ro' , isa => 'Web::Summarizer::SentenceBuilder' , lazy => 1 , builder => '_sentence_builder_builder' );
=cut

# fold id
# TODO : must be removed ultimately ==> UrlData need to know what fold id it is attached to ==> Category::Data needs to be attached to a fold id
has 'fold_id' => ( is => 'ro' , isa => 'Num' , required => 1 );

# return intermediate summaries
# TODO : move this down to a subclass => not all systems will generate intermediate summaries
has 'return_intermediate_summaries' => ( is => 'ro' , isa => 'Bool' , default => 1 );
has 'intermediate_summaries' => ( is => 'ro' , isa => 'ArrayRef' , default => sub { [] } );

# sentence analyzer
# TODO : promote to parent class ?
has 'sentence_analyzer' => ( is => 'rw' , isa => 'Web::Summarizer::SentenceAnalyzer' , predicate => 'has_sentence_analyzer' );

# output directory
has 'output_directory' => ( is => 'ro' , isa => 'Str' , required => 0 , predicate => 'has_output_directory' );

# summarizer id
sub summarizer_id {
    my $this = shift;
    my $summarizer_id = join( "-" , $this->system );
}

# summarize a URL/object
# TODO : can we add signature requirements ?
# in : instance object
requires 'summarize';

# get output directory
# TODO : add a "shared" argument so that private directories don't have to be requested by passing the summarizer id
sub get_output_directory {

    my $this = shift;
    
    if ( ! $this->has_output_directory ) {
	# Return a Str to allow for minimum constraints on directory path fields
	# TODO : can we do something cleaner ?
	return '';
    }

    my $directory_path = join( "/" , $this->output_directory , @_ );
    if ( ! -d $directory_path ) {
	mkpath $directory_path;
    }

    return $directory_path;

}

after 'error' => sub {
    my $this = shift;
    die "Aborting ...";
};

sub _log_system_configuration {

    my $this = shift;

    # TODO: start using decent logging library ?                                                                                                                                             
    print STDERR "\n";
    print STDERR "****************************************************************************************************************************\n";
    print STDERR "Decoder: " . $this->decoder_class . "\n";
###    if ( $this->has_learner_class ) {                                                                                                                                                     
###     print STDERR "Learner: " . $this->learner_class . "\n";                                                                                                                              
###    }                                                                                                                                                                                     
    print STDERR "Edge Cost: " . $this->edge_cost_class . "\n";
    print STDERR "Cluster limit: " . $this->reference_cluster_limit . "\n";
    print STDERR "****************************************************************************************************************************\n\n";

}

# state
# TODO : to be reinitialized when summarize is called
has 'state' => ( is => 'ro' , isa => 'Web::Summarizer::State' , init_arg => undef , lazy => 1 , builder => '_state_builder' );
sub _state_builder {
    my $this = shift;
    my $state = new Web::Summarizer::State;
    return $state;
}

sub log_summarizer_stat {

    my $this = shift;
    my $key = shift;
    
    print STDERR join( "\t" , $key , @_ ) . "\n";

}

###__PACKAGE__->meta->make_immutable;

1;
