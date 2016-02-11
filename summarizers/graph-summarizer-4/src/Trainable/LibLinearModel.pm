package Trainable::LibLinearModel;

use strict;
use warnings;

# TODO : this should be a generic package
use FeatureMapper;

use Algorithm::LibLinear;
##use Function::Parameters qw/:strict/;

#use Moose::Role;
use MooseX::Role::Parameterized;

parameter model_file => (
    isa => 'Str',
    required => 1
    );

# TODO : how do we get rid of this parameter ? redundant with feature_mapping
parameter map_features => (
    isa => 'Bool',
    default => 0
    );

parameter feature_mapping => (
    isa => 'Str'
    );

role {

    my $p = shift;
    my $model_file = $p->model_file;
    my $map_features = $p->map_features;
    my $feature_mapping = $p->feature_mapping;

# TODO : ultimately would this be the right thing to do ?
#with( 'Trainable' );
    
    # model base
    has 'model_base' => ( is => 'ro' , isa => 'Str' , required => 1 );
    
    # model file
    has 'model_file' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_model_file_builder' );
    method '_model_file_builder' => sub {
	my $this = shift;
	return $this->_get_model_file( $model_file );
    };

    method '_get_model_file' => sub {
	my $this = shift;
	my $local_filename = shift;
	return join( "/" , $this->model_base , $local_filename );
    };
    
    # model
    has '_model' => ( is => 'ro' , isa => 'Algorithm::LibLinear::Model' , init_arg => undef , lazy => 1 , builder => '_model_builder' );
    method '_model_builder' => sub {
	my $this = shift;
	return Algorithm::LibLinear::Model->load( filename => $this->_get_model_file( $model_file ) );
    };

    if ( $map_features ) {
	has 'feature_mapper' => ( is => 'ro' , isa => 'FeatureMapper' , init_arg => undef , lazy => 1 , builder => '_feature_mapper_builder' );
	method _feature_mapper_builder => sub {
	    my $this = shift;
	    return new FeatureMapper( feature_mapping_file => $this->_get_model_file( $feature_mapping ) );
	};
    }
        
    # predict probability
    # TODO : how can we enable Function::Parameters ?
    method 'predict_probability' => sub {
	my $self = shift;
	my %params = @_;
	my $features = $params{ 'features' };
	return $self->_model->predict_probability( feature => $map_features ? $self->feature_mapper->map_features( $features ) : $features );
    };

};

1;
