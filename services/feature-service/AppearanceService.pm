package AppearanceService;

use strict;
use warnings;

use AppearanceModel::Individual;
use Environment;

use FindBin;

use Moose;
#use MooseX::NonMoose::InsideOut;
use MooseX::NonMoose;

extends 'JSON::RPC::Procedure';

# conditional data base
has 'models_base' => ( is => 'ro' , isa => 'Str' , default => Environment->data_models_base );

# appearances models
has 'appearance_models' => ( is => 'ro' , isa => 'HashRef[AppearanceModel]' , init_arg => undef , default => sub { {} } );

# feature value threshold
has 'feature_value_threshold' => ( is => 'ro' , isa => 'Num' , required => 1 );

# feature mapping
has 'feature_mapping' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_feature_mapping_builder' );
sub _feature_mapping_builder {

    my $this = shift;
    
    # Note: for now all n-gram orders are merged into a single data file
    my $feature_mapping_file = join( "/", $this->models_base , "abstractive/summary_abstractive.significance.selection.features.map" );

    my %feature_mapping;
    if ( open FEATURE_MAPPING_FILE , $feature_mapping_file ) {

	while ( <FEATURE_MAPPING_FILE> ) {

	    chomp;

	    my @fields = split /\t/ , $_;
	    my $feature_key_raw = shift @fields;
	    my $feature_key_mapped = shift @fields;
	    my $feature_value = shift @fields;

	    if ( $feature_value < $this->feature_value_threshold ) {
		next;
	    }

	    $feature_mapping{ $feature_key_raw } = $feature_value;

	}
    }
    else {
	die "Unable to load abstractive feature mapping file ($feature_mapping_file) : $!";
    }

    return \%feature_mapping;
    
}

sub map_appearance_features {

    my $this = shift;
#    my @arg = @_;

#    my $raw_features = $arg[ 0 ][ 0 ];
    my $raw_features = shift;
    my %mapped_features;

    foreach my $raw_feature_key (keys( %{ $raw_features } )) {
	my $mapped_key = $this->feature_mapping->{ $raw_feature_key };
	if ( defined( $mapped_key ) ) {
	    $mapped_features{ $mapped_key } = $raw_features->{ $raw_feature_key };
	}
    }

    return \%mapped_features;

}

sub appearance {

    my $this = shift;
    my @arg = @_;

    my $model_type = $arg[ 0 ][ 0 ];
    my $raw_features = $arg[ 0 ][ 1 ];

    # 1 - map features to model space
    my $mapped_features = $this->map_appearance_features( $raw_features );

    # 2 - run appearance model
    my $model_predictions = $this->get_appearance_model( $model_type )->run( $mapped_features );

    return $model_predictions;

}

sub get_appearance_model {

    my $this = shift;
    my $model_type = shift;

    if ( ! defined( $this->appearance_models->{ $model_type } ) ) {
	$this->appearance_models->{ $model_type } = $this->load_appearance_model( $model_type );
    }

    return $this->appearance_models->{ $model_type };

}

sub load_appearance_model {
    
    my $this = shift;
    my $model_type = shift;

    # currently we ignore the model type ?
    my $appearance_model = new AppearanceModel::Individual(
	individual_models_list => join( "/" , $this->models_base , 'abstractive/summary_abstractive.predictive.models.list' ) ,
	make_probability_distribution => 1
	);

    # TODO : how can we avoid this step or at least automate it ?
    $appearance_model->init;

    return $appearance_model;

}

# no need to fiddle with inline_constructor here
__PACKAGE__->meta->make_immutable;

1;
