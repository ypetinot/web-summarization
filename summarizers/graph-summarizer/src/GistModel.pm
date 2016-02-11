package GistModel;

# implementation of our statistical model of gists

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use GistGraph;
use GistGraph::AppearanceModel;
use GistGraph::Model;

# gist graph serialization file
our $GIST_MODEL_SERIALIZATION_FILENAME = "gist_model.json";

extends('GistGraph::Model');
with Storage('format' => 'JSON', 'io' => 'File');

# fields

# model root
has 'model_root' => (is => 'ro', isa => 'Str', required => 1);

# data root
has 'raw_data' => (is => 'rw', isa => 'Category::Data', required => 1, traits => [ 'DoNotSerialize' ]) ;

# underlying gist graph
has 'gist_graph' => (is => 'rw', isa => 'GistGraph', required => 1, traits => [ 'DoNotSerialize' ], builder => '_load_gist_graph', lazy => 1);

# appearance model
has 'np_appearance_model' => (is => 'rw', isa => 'GistGraph::AppearanceModel', init_arg => undef, traits => [ 'DoNotSerialize' ], predicate => 'has_np_appearance_model');

# appearance_models
has 'np_appearance_models' => (is => 'rw', isa => 'HashRef', init_arg => undef, traits => [ 'DoNotSerialize' ], default => sub { {} });

# current inference model
has 'inference_model' => (is => 'rw', isa => 'GistGraph::InferenceModel', traits => [ 'DoNotSerialize' ], lazy => 1, default => sub { undef; }, predicate => 'has_inference_model');

# load gist graph
sub _load_gist_graph {

    my $this = shift;
    
    my $gist_graph = GistGraph->restore( $this->raw_data() , $this->model_root() , 1 );

    return $gist_graph;

}

# load appearance model
sub _load_appearance_model {

    my $this = shift;
    my $appearance_model_type = shift;
    my $appearance_model_parameters = shift;
    
    my $appearance_model = $this->_load_model_module( $appearance_model_type )->restore( $this->model_root() , $this->gist_graph() , $appearance_model_parameters );

    return $appearance_model;

}

# reset model (and sub-models)
sub reset {

    my $this = shift;

    # reset appearance model
    if ( $this->has_np_appearance_model() ) {
	$this->np_appearance_model()->reset();
    }

    # reset inference model
    if ( $this->has_inference_model() ) {
	$this->inference_model()->reset();
    }

}

# train NP appearance model
# joint noun-phrase appearance model training (using feature obtained from the raw content)
sub train_appearance_model {

    my $this = shift;
    my $appearance_model_type = shift;
    my $appearance_model_parameters = shift;

    my $gist_graph = $this->gist_graph();

    my $np_appearance_model = $this->_load_model_module( $appearance_model_type )->new( gist_graph => $gist_graph , parameters => $appearance_model_parameters ) ;
    $np_appearance_model->train();

    # set appearance model for this instance
    $this->np_appearance_model( $np_appearance_model );

    # finally we keep track of this appearance model for future usage
    my $appearance_model_key = $np_appearance_model->key();
    $this->np_appearance_models()->{ $appearance_model_key } = $np_appearance_model;

    return $np_appearance_model;

}

# TODO: add method to return arbitrary directory for supporting/related data (e.g. plots)

# serialization filename
sub get_serialization_filename {

    my $this = shift;
    my $model_root = shift || $this->model_root();

    return join( "/" , $model_root , $GIST_MODEL_SERIALIZATION_FILENAME );

}

# write out
sub write_out {

    my $this = shift;

    # write out all appearance models that were created by this GistModel
    foreach my $appearance_model_key (keys %{ $this->np_appearance_models() }) {
	
	my $np_appearance_model = $this->np_appearance_models()->{ $appearance_model_key };
	
        # Serialize appearance model
	$np_appearance_model->write_out( $this->model_root() );

    }

    # Serialize gist model
    $this->store( $this->get_serialization_filename() );

}

# evaluate model for a specific instance
sub apply {

    my $this = shift;
    my $url_data = shift;

    # run inference on appearance model
    if ( $this->has_np_appearance_model() ) {
	$this->np_appearance_model()->run_inference( $url_data );
    }

}

# For now a GistModel is just a shallow shell around an appearance model and an inference model
=pod 
# restore
sub restore {

    my $that = shift;
    my $raw_data = shift;
    my $model_root = shift;
    my $appearance_model_type = shift;

    my $gist_model = undef;
    my $serialization_filename = $that->get_serialization_filename( $model_root );

    # load from serialized form
    if ( -f $serialization_filename ) {

	$gist_model = $that->load( $serialization_filename );
	
	# *****************************************************************************************
	# restore raw data field

	# TODO: can we make this more transparent ?
	
	# set raw data
	$gist_model->raw_data( $raw_data );
	
	# *****************************************************************************************

	# set appearance model type
	if ( defined( $appearance_model_type ) ) {
	    $gist_model->np_appearance_model_type( $appearance_model_type );
	}
	
	# restore appearance model
	$gist_model->_load_model_module();
	my $appearance_model = $gist_model->np_appearance_model_type()->restore( $gist_model->model_root() , $gist_model->gist_graph() );
	$gist_model->np_appearance_model( $appearance_model );
	
    }

    return $gist_model;

}
=cut

# get dump of the model state
# (for now this only includes individual nodes' appearance information)
sub get_model_state {

    my $this = shift;

    my %state;

    # collect appearance information using appearance model
    my $np_appearance_model_state = $this->np_appearance_model()->get_state();
    $state{ 'appearance-model-state' } = $np_appearance_model_state;
    
    return \%state;

}

# set appearance model
sub set_appearance_model {

    my $this = shift;
    my $appearance_model_type = shift;
    my $appearance_model_parameters = shift;

    # fetch model key if available
    my $appearance_model_key = $this->_get_appearance_model_key( $appearance_model_type , $appearance_model_parameters );
    
    # lookup appearance model
    if ( defined( $appearance_model_key ) ) {

	my $appearance_model = $this->np_appearance_models()->{ $appearance_model_key };
    
	# return model associated with this key, if any
	if ( ! defined( $appearance_model ) ) {

	    # attempt to load a pre-trained model
	    $appearance_model = $this->_load_appearance_model( $appearance_model_type , $appearance_model_parameters );
	    
	}

	$this->np_appearance_model( $appearance_model );

	# reset internal structure
	$this->reset();

	return 1;

    }

    print STDERR "Requested appearance model is unavailable: $appearance_model_type ...\n";
    return 0;

}

# set inference model
sub set_inference_model {

    my $this = shift;
    my $inference_model_class = shift;
    my $inference_model_mode = shift;

    $this->_load_model_module( $inference_model_class );

    my $inference_model = new $inference_model_class( 'mode' => $inference_model_mode );

    # set current inference model
    $this->inference_model( $inference_model );

    return 1;

}

# check whether a specific appearance model is available
sub has_appearance_model {

    my $this = shift;
    my $appearance_model_type = shift;
    my $appearance_model_parameters = shift;

    # get mode id
    my $appearance_model_id = $this->_get_appearance_model_key( $appearance_model_type , $appearance_model_parameters );
    
    if ( defined( $this->np_appearance_models()->{ $appearance_model_id } ) ) {
	return $appearance_model_id;
    }

    return undef;

}

# get appearance model key
sub _get_appearance_model_key {

    my $this = shift;
    my $appearance_model_type = shift;
    my $appearance_model_parameters = shift;

    my $appearance_model_id = $this->_load_model_module( $appearance_model_type )->key( $appearance_model_parameters );

    return $appearance_model_id;

}

# run inference given for the specified UrlData instance
sub run {

    my $this = shift;
    my $url_data = shift;

    # apply gist model to the target instance
    $this->apply( $url_data );

    # run actual inference (to be implemented by sub-classes)
    return $this->inference_model()->run_inference( $this , $url_data );

}

no Moose;

1;
