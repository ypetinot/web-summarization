package Learner::StructuredPerceptronLearner;

use strict;
use warnings;

use Web::Summarizer::SentenceAnalyzer;

use Statistics::Basic qw(:all);

use Moose;
use namespace::autoclean;

extends 'Learner';

use List::Util qw/min/;
use List::MoreUtils qw/uniq/;

my $DEBUG = 2;

# use averaging
has 'averaged' => ( is => 'ro' , isa => 'Bool' , default => 0 , required => 0 );

# compute weights
sub _compute_weights {
    
    my $this = shift;
    my $model = shift;
    my $decoder = shift;
    my $training_set = shift;

    my $iterations = $this->iterations();
    my $use_averaged = $this->averaged();

    # 1 - reference feature vectors
    
    # No specialization - we now annotate the slot with is filler ?
    # During decoding, if slot, we give multiple options for the corresponding value ...
    # TODO : move this call to parent class ?
    
    # 3 - featurization of true path --> based on a fixed set of (descriptive) meta-features
    
    # How does a change in feature weight affect the occurence / non-occurence of that feature ?
    # Current model: cost of feature directly (1-to-1) affects cost of edge (featurization not coming from path !)
    # New model: cost of feature = cost of having a specific construct in the path --> cannot have global features (maybe accumulative ones at least ?) since they don't mean anything at the edge level ...
    
    # Features:
    # Frequency in known paths (i.e. prior)
    
    # Is this a slot + slot features ( is the context ... / is the preceeding word ... / is ... )
    
    my %w;
    my %optimal_outputs;
    my %gold_outputs;

    my %w_averaged;
    my $n_updates = 0;

    # sentence analyzer for tracking/debugging purposes
    my $sentence_analyzer = new Web::Summarizer::SentenceAnalyzer();

    # 2 - iterate
    my $ALPHA = 0.1;
    print STDERR "Structured perceptron now learning ...\n";
    for (my $i=0; $i<$iterations; $i++) {
	
	my $has_path_mismatch = 0;
	my $updated = 0;
	
	my %w_copy = %w;
	
	# 2 - 1 - iterate over training samples
	foreach my $training_set_entry (@{ $training_set }) {
	    
	    $n_updates++;

	    my $training_set_instance = $training_set_entry->[ 0 ];
	    my $training_set_instance_id = $training_set_instance->id();

	    # TODO : technically we could compute the gold features here
	    my $training_set_gold_path_features = $training_set_entry->[ 1 ];

	    my $updated_url = 0;

	    # \phi(x,y)
	    
	    if ( $DEBUG > 2 ) {

		# make sure the feature weights match the ones stored in the featurized model
		my $model_weights = $model->feature_weights();
		my $weight_mismatch_1 = scalar( grep { $w{ $_ } != $model_weights->{ $_ } } keys( %{ $model_weights } ) );
		my $weight_mismatch_2 = scalar( grep { $w{ $_ } != $model_weights->{ $_ } } keys( %w ) );

		if ( $weight_mismatch_1 || $weight_mismatch_2 ) {
		    print STDERR "Weight mismatch !\n";
		}

		print STDERR join( " " , map { $_ . ":" . $w{ $_ } } keys( %w )) . "\n";

	    }

	    # decode training sample using current w
	    # We don't need to update the graph, the weights can be absorbed dynamically (beam search !) ==> what does this mean ??
	    # CURRENT : what if training_set_instance has a model instance ? i.e. a combination of the model and a data instance
	    # TODO : add checks (compile time ?) to make sure that the decoder and the space instances are indeed compatible
	    # CURRENT : separate the space from the search criterion (i.e. the model) ==> the decoder should take as a parameter some sort of scoring function that is compatible with the decoding mode ...


=pod
	    my $y_optimal = $decoder->( $training_set_instance->input_object , 1 );
	    $optimal_outputs{ $training_set_instance_id } = $y_optimal;

	    ###my $y_optimal_features = $model->featurize( $training_set_instance , $y_optimal );
	    # TODO : maybe this operation should be moved to a super-class ? need templated iterated learner class ?	    
	    # TODO : how can we avoid creating a temporary clone ?
	    my $training_set_instance_clone = $training_set_instance->clone;
	    $training_set_instance_clone->output_object( $y_optimal );
	    my $y_optimal_features = $training_set_instance_clone->featurize;
=cut

	    # TODO : check parameters
	    my $y_optimal_features = $decoder->( $training_set_instance->input_object );

	    # 2 - 1 - 2 - update weights based on features (energy) error
	    # w is in feature space
	    my $update_feature_ids = feature_diff( $training_set_gold_path_features , $y_optimal_features );
	    foreach my $feature_id (@{ $update_feature_ids }) {
		
		$has_path_mismatch++;

		my $feature_reference = $this->_feature_value( $training_set_gold_path_features , $feature_id );
		my $feature_current = $this->_feature_value( $y_optimal_features , $feature_id );
		
		my $feature_delta = $feature_reference - $feature_current;
		if ( $feature_delta ) {
		    
		    $updated++;
		    $updated_url++;
		    
		    if ( $DEBUG > 2 ) {
			print STDERR "\tUpdating feature $feature_id --> $feature_delta\n";
		    }

		    # compute new feature weight value
		    my $feature_weight_updated_value = $this->_feature_weight( \%w , $feature_id ) - $ALPHA * $feature_delta;		    

		    $w{ $feature_id } = $feature_weight_updated_value;
		    $model->update_feature_weight( $feature_id , $feature_weight_updated_value );
		    
		}
		
	    }

	    # update average weight vector
	    if ( $use_averaged ) {
		map { $w_averaged{ $_ } += $w{ $_ }; } keys( %w );
	    }
	    	    
	    # 2 - 1 - 3 - --> if in shared mode we average (?) connected weights
	    # --> effective number of model parameters depends on mode: shared/non-shared
	    # TODO
	    
	    $this->debug();
	    
	}

	#$ALPHA /= 5;
	
	if ( ! $has_path_mismatch ) {
	    $this->warn("Perfect iteration !");
	}
	
    }

    # if we're using averaging
    if ( $use_averaged ) {
	map { $w_averaged{ $_ } /= $n_updates; $model->update_feature_weight( $_ , $w_averaged{ $_ } ); } keys( %w_averaged );
	return \%w_averaged;
    }

    return \%w;

}

=pod to be removed
sub _path_match {

    my $path1 = shift;
    my $path2 = shift;

    my $path1_length = $path1->length();
    my $path2_length = $path2->length();
    if ( $path1_length != $path2_length ) {
	return 0;
    }

    my $match_length = min( $path1_length , $path2_length );
    for ( my $i = 0; $i < $match_length; $i++ ) {
	if ( $path1->get_element( $i ) ne $path2->get_element( $i ) ) {
	    return 0;
	}
    }

    return 1;

}
=cut

# feature diff
# TODO: standard implementation for feature_diff ?
sub feature_diff {
    
    my $features_1 = shift;
    my $features_2 = shift;
    
    my @diff_keys = grep { ! defined( $features_1->{ $_ } ) || ! defined( $features_2->{ $_ } ) || ( $features_1->{ $_ } != $features_2->{ $_ } ) } uniq ( keys( %{ $features_1 } ) , keys( %{ $features_2 } ) );

    return \@diff_keys;

}

__PACKAGE__->meta->make_immutable;

1;
