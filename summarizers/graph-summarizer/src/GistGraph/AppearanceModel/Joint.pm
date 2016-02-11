package GistGraph::AppearanceModel::Joint;

# Base class for Joint (whether correlated or not) Appearance Models

use strict;
use warnings;

use Moose;

extends 'GistGraph::AppearanceModel';

# Fields

# appearance model
has 'classifier' => (is => 'rw', isa => 'NPModel::BinaryClassifier');

# train model
sub _train {

    my $this = shift;
    my $instances = shift;
    my $ground_truth = shift;

    my $feature_set = undef;
    my $training_documents_features = undef; 

    # generate a multi-label classifier for every single label (node) in the gist graph
    my @node_ids = @{ $this->gist_graph()->sorted_nodes(1) };
    
    my $multi_label_classifier = ( $this->parameters()->{ 'learner' } )->new(
	base_directory => $this->get_support_directory(),
	bin_root => $FindBin::Bin,
	contents => $instances,
	description => join("::",$this->parameters()->{ 'learner' },$this->key()),
	features => $this->parameters()->{ 'features' }
	);
    $multi_label_classifier->initialize( $feature_set , \@node_ids ); 
    $multi_label_classifier->train( $ground_truth );
    $multi_label_classifier->finalize();
    
    # set reference to classifier
    $this->classifier( $multi_label_classifier );
 
}

# run inference
sub _run_inference {

    my $this = shift;
    my $url_data = shift;

    # run classification for underlying model
    my $node_appearances = $this->classifier()->classify( $url_data );

    # finally update appearance field
    map { $this->appearance()->{ $_ } = $node_appearances->{$_}; } keys( %{ $node_appearances } );

}

no Moose;

1;
