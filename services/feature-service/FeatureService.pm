package FeatureService;

use strict;

use FindBin;

use Vocabulary;

use Moose;
#use MooseX::NonMoose::InsideOut;
use MooseX::NonMoose;

extends 'JSON::RPC::Procedure';

# ODP/DMOZ vocabulary
# Used only if specified at construction-time
has 'vocabulary' => ( is => 'ro' , isa => 'Vocabulary' , builder => '_build_vocabulary' , lazy => 1 , required => 0 );

# conditional data base
has 'data_directory_base' => ( is => 'ro' , isa => 'Str' , required => 1 );

# conditional data
has 'conditional_data' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } , lazy => 1 ); 

# chi square threshold for conditional data
has 'chi_square_threshold' => ( is => 'ro' , isa => 'Num' , default => 0 );

sub _build_vocabulary {
 
    my $this = shift;
    
    return Vocabulary->load( join( "/" , $this->data_directory_base() , 'dmoz.vocabulary.features' ) );
    
}

sub BUILD {

    my $this = shift;
    
    # Pre-load vocabulary, this will take some time ...
    $this->vocabulary();

}

sub echo {
    # first argument is JSON::RPC::Server object.
    return $_[1];
}
 
#sub compute_feature : Public(a:num, b:num) { # sets value into object member a, b.
#    my ($s, $obj) = @_;
#    # return a scalar value or a hashref or an arryaref.
#    return $obj->{a} + $obj->{b};
#}

sub get_word_entry {

    my $this = shift;
    my @arg = @_;

    my $word = $arg[ 0 ][ 0 ];
    my $entry = $this->vocabulary()->get_entry( $word );

    return $entry;

}

sub get_word_semantics {
    
    my $this = shift;
    my @arg = @_;

#    if ( ! defined( $vocabulary ) ) {
#	$vocabulary = Vocabulary->load( $ENV{ 'VOCABULARY_FEATURES' } );
#    }

    my $word = $arg[ 0 ][ 0 ];
    my $semantic_representation = $this->vocabulary()->semantic_representation( $word );

    my $result = undef;
    if ( $semantic_representation ) {
	$result = $semantic_representation->coordinates();
    }

    return $result;

}

sub get_conditional_features {

    my $this = shift;
    my $args = shift;

    my $target_modality = $args->[ 0 ];
    my $instance_ngram_data = $args->[ 1 ];

    # TODO : clean this up (the "ngrams.%d" portion should become a facet / sub-facet field marked by ::)
    $target_modality =~ s/\.ngrams.*$//sg;

    # make sure we have loaded the target conditional data
    if ( ! defined $this->conditional_data()->{ $target_modality } ) {
	$this->load_conditional_data( $target_modality );
    }

    # get conditional data for the target modality
    my $target_modality_conditional_data = $this->conditional_data()->{ $target_modality };

    my $conditional_features = {};

    # iterate over the instance ngrams
    foreach my $instance_modality_ngram (keys( %{ $instance_ngram_data } )) {

	my $target_conditional_features = $target_modality_conditional_data->{ $instance_modality_ngram };

	if ( defined( $target_conditional_features ) ) {
	    # TODO : how do we handle overlapping conditional data ?
	    $conditional_features->{ $instance_modality_ngram } = $target_conditional_features;
	}

    }

    return $conditional_features;

}

# each (data) feature maps to a set of non-zero summary object appearance probability
sub load_conditional_data {

    my $this = shift;
    my $modality = shift;
    
    # Note: for now all n-gram orders are merged into a single data file
    # This may change in the feature, but no need for something more complicated right now 
    my $conditional_data_file = join( "/", $this->data_directory_base() , join( "." , "dmoz" , $modality , "conditional" ) , join( "." , $modality , "features" ) );

    my $conditional_data = {};
    if ( open CONDITIONAL_DATA_FILE , $conditional_data_file ) {

	while ( <CONDITIONAL_DATA_FILE> ) {

	    chomp;

	    my @fields = split /\t/ , $_;
	    my $summary_object = shift @fields;
	    my $feature_surface = shift @fields;
	    my $count_joint_appearances = shift @fields;
	    my $chi_square_score = shift @fields;
	    my $conditional_probability = shift @fields;

	    if ( $chi_square_score < $this->chi_square_threshold() ) {
		next;
	    }

	    # feature conditional data is a (sorted ?) list of non-zero conditional probability given the current 
	    if ( ! defined( $conditional_data->{ $feature_surface } ) ) {
		$conditional_data->{ $feature_surface } = [];
	    }

	    push @{ $conditional_data->{ $feature_surface } } , [ $summary_object , $count_joint_appearances , $chi_square_score , $conditional_probability ];

	}
    }
    else {
	print STDERR "Unable to load conditional data file ($conditional_data_file): $!";
    }

    $this->conditional_data()->{ $modality } = $conditional_data;

}

no Moose;

# no need to fiddle with inline_constructor here
__PACKAGE__->meta->make_immutable;

1;
