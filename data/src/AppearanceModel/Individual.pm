package AppearanceModel::Individual;

use strict;
use warnings;

use Algorithm::LibLinear;
use List::Util qw[min max];

use Moose;
use namespace::autoclean;

with 'AppearanceModel';

our $MODEL_ENTRY_KEY_ID      = "id";
our $MODEL_ENTRY_KEY_MODEL   = "model";
our $MODEL_ENTRY_KEY_SURFACE = "surface";

# turn into probability distribution
has 'make_probability_distribution' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# individual models list
# TODO : should this be a full-fledged configuration file ?
# TODO : find better name for this field ?
has 'individual_models_list' => ( is => 'ro' , isa => 'Str' , required => 1 );

# individual models
# TODO : find better name for this field ?
has 'individual_models' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_individual_models_list' );
sub _individual_models_list {

    my $this = shift;
    my $models_list_file = $this->individual_models_list;
    
    my @term_models;

    open ( MODELS_LIST , $models_list_file ) || die "Unable to open models list file ($models_list_file): $!";
    while ( <MODELS_LIST> ) {
	
	chomp;
	
	my @fields = split /\t/ , $_;
	my $term_surface = shift @fields;
	my $term_id = shift @fields;
	my $term_model_file = shift @fields;

	# load model
	# TODO : abstract out the dependency on Algorithm::LibLinear
	my $term_model = Algorithm::LibLinear::Model->load( filename => $term_model_file );

	push @term_models , +{ $MODEL_ENTRY_KEY_ID => $term_id , $MODEL_ENTRY_KEY_SURFACE => $term_surface , $MODEL_ENTRY_KEY_MODEL => $term_model };

    }
    close MODELS_LIST;

    return \@term_models;

}

sub init {

    my $this = shift;

    # trigger loading of individual models
    $this->individual_models;

}

sub run {
    
    my $this = shift;
    my $features = shift;
    my $target_term = shift; # optional but possible

    my %predictions;

    my @model_entries = @{ $this->individual_models };
    foreach my $model_entry (@model_entries) {
	my $term = $model_entry->{ $MODEL_ENTRY_KEY_SURFACE };
	my $model = $model_entry->{ $MODEL_ENTRY_KEY_MODEL };
	my @model_prediction = $model->predict_values( feature => $features );
	$predictions{ $term } = $model_prediction[ 0 ][ 0 ];
    }

    if ( $this->make_probability_distribution ) {
	
	my $prediction_min = min( values( %predictions ) );
	my $normalizer = 0;

	map { $predictions{ $_ } += $prediction_min; $normalizer += $predictions{ $_ }; } keys( %predictions );
	map { $predictions{ $_ } /= $normalizer; } keys( %predictions );

    }

    return \%predictions;

}

__PACKAGE__->meta->make_immutable;

1;
