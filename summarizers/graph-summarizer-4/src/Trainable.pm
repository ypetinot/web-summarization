package Trainable;

# Role for all trainable systems/functions
# TODO : would it be more meaningful to apply this role to Model instances instead ?

# TODO : parameterized this role as much as possible

# Abstraction of a machine that manages the learning process - thus this machine has access to a training set (and possibly a dev set) that is available either as a batch (batch training) or as an incoming stream (online training).

# TODO : create Manager super-class
# The manager is intended to control the learning process by
# * creating actual set of instances to be used for training and appropriate to the model/learner considered
# * providing, when needed, a dev set to the learner
# * etc.

use strict;
use warnings;

# TODO : ultimately this should be turned into a Method trait, since what we want to do is basically learn a specific the model behind a specific function (how would the model be specified though ?)
# http://jjnapiorkowski.typepad.com/modern-perl/2010/08/parameterized-roles-and-method-traits-redo.html#.U17sRnWx3D4

#use Moose::Role;
use MooseX::Role::Parameterized;

parameter mapping_method => (
    isa => 'Str',
    required => 1
    );

role {

    my $p = shift;
    my $mapping_method = $p->mapping_method;

    # requires the mapping method (obviously)
    requires($mapping_method);

    # The system to which this role is applied is a decoder (whether or not it is explicitly designated as such) equipped with a model
    # TODO : how can we bring this back in ?
    #requires('model');

    # TODO add support (sub-class ?) for streaming/online training/dev sets ?

    # dev set
    # [ [ instance_in , instance_out ] , ... ]
    has 'dev_set' => ( is => 'ro' , isa => 'ArrayRef' , default => sub { [] } );

    # learner class
    # TODO : add role parameter to specificy expected learner type/role requirement based on the type of model
    has 'learner_class' => ( is => 'ro' , isa => 'Str' , required => 1 , predicate => 'has_learner_class' );

    # learner params
    has 'learner_params' => ( is => 'ro' , isa => 'HashRef[Str]' , default => sub { {} } );

    # learner
    # TODO : does the learner really belong here ?
    has 'learner' => ( is => 'ro' , isa => 'Learner' , init_arg => undef , lazy => 1 , builder => '_learner_builder' );
    method "_learner_builder" => sub {
	my $this = shift;
	# instantiate learner
	# Note : the learner must be a sub-class of WordGraph::Learner
	my %learner_params = %{ $this->learner_params };
	# TODO : add Trait to *_class attributes so that the corresponding class gets loaded automatically
	my $learner = ( Web::Summarizer::Utils::load_class( $this->learner_class ) )->new( %learner_params );	
	return $learner;
    };
    
    method "train_iteration" => sub {
	
	my $this = shift;
	my $input_object = shift;
	my $output_object = shift;
	
	# 1 - run current procedure (i.e. decode) to get output using model's current state
	my $generated_output_object = $this->summarize( $input_object );
	
	# 2 - compare generated output with true output
	# TODO ?
	
	# 3 - request model update
	$this->request_model_update( $input_object , $output_object , $generated_output_object );

    };
        
    # TODO : online learning model ? ==> different model ==> instances seen only once ?
    method "train_online" => sub {
	
	my $this = shift;
	my $target_data = shift;
	my $target_summary = shift;
	
	# 1 - submit instance to manager
	
    };
    
    # Note : assuming batch supervised learning for now
    method "train_batch" => sub {
	
	my $this = shift;
	my $instances_training = shift;
	
	# [ [ transformed_instance_in , transformed_instance_out ] , ... ]
	# CURRENT : when transforming the instance, we basically tie it to the model , so why not also tie it to the decoding process (and the associated search space) ?
        ###    my $transformed_instances_training = $this->model->transform_instances( $instances_training );
	
	# 2 - featurize instances (i.e. produce ground truth features)
	# [ [ transformed_instance_in , featurizable instance ] , ... ]
	# TODO : why ???
	###my @featurized_training_instances = map { [ $_->[ 0 ] , $_->[ 1 ]->featurize ] } @{ $transformed_training_instances };

	# 1 - decode+featurize function
	my $decode_and_featurize = sub {
	    my $instance_in = shift;
	    my $instance_out = shift;
#	    print STDERR "Requesting features for : " . join( " / " , $instance_in->[ 0 ]->id , $instance_out ? $instance_out->verbalize : '' ) . "\n";
	    my $decoded_object_featurized = $this->$mapping_method( $instance_in , 1 , $instance_out );
	    return $decoded_object_featurized;
	};
	
	my @featurized_instances_training;
	foreach my $instance_training (@{ $instances_training }) {
	    my $instance_training_featurized = $decode_and_featurize->( $instance_training->input_object , $instance_training->output_object );
	    push @featurized_instances_training , [ $instance_training , $instance_training_featurized ];
	}

	# Note : the search space is abstracted by the decoder / the decoder is fundamentally controlled by the model (state)
#	my $trained_model = $this->learner->run( $this->model , sub { return $this->$mapping_method( @_ ) } , \@featurized_instances_training );
	
	# Learn manyfold in feature space (oblivious to the actual types of the input/output objects)
	my $trained_model = $this->learner->run( $this->model , $decode_and_featurize , \@featurized_instances_training );
	
	return $trained_model;
	
    };

};

1;
