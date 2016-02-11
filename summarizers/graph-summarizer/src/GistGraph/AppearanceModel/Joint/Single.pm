package GistGraph::AppearanceModel::Joint::Single;

# Appearance Models where a single decision model is shared by all nodes in the gist graph 

use strict;
use warnings;

use Moose;

#TODO: is this really a joint model ?
extends 'GistGraph::AppearanceModel::Joint';

# Fields

# train model
sub train {

    my $this = shift;

    my @full_ground_truth = @{ $this->ground_truth() };
    my $contents = _prepare_data( $this->gist_graph()->raw_data()->url_data() );

    my $feature_set = undef;
    my $training_documents_features = undef; 

    # call to underlying training method
    $this->_train( $contents , \@full_ground_truth );

    # TODO: Should the feature set be a field in the AppearanceModel class ?
    if ( ! defined($feature_set) ) {
	$feature_set = $binary_classifier->get_feature_set();
    }
   
}

# run inference
sub run_inference {

    my $this = shift;
    my $url_data = shift;

    # prepare data
    my $content = _prepare_data( [ $url_data ] );

    # run classification for underlying model
    my $node_appearances = $this->_run_inference( $content->[0] );

    # finally update appearance field
    map { $this->appearance()->{ $_ } = $node_appearances->{$_}; } keys( %{ $node_appearances } );

}

no Moose;

1;
