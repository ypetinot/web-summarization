package GistGraph::AppearanceModel::Smoothable;

# The smoothable appearance model allows the adjunction of a smoothing distribution to an otherwise unsmoothed appearance model

use strict;
use warnings;

use Moose;

use GistGraph::AppearanceModel;
extends 'GistGraph::AppearanceModel';

has 'base_model' => (is => 'rw', isa => 'GistGraph::AppearanceModel', traits => [ 'DoNotSerialize' ]);

has 'smoothing_component' => (is => 'rw', isa => 'GistGraph::AppearanceModel', traits => [ 'DoNotSerialize' ]);

# keep track of known nodes
has 'known' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# train model
sub train {

    my $this = shift;

    # Not a trainable model for now
    # TODO: learn smoothing interpolation factors for the target category ?

}

# run inference
sub _run_inference {

    my $this = shift;
    my $url_data = shift;

    # Retrieve smoothing distribution for this 
    my $ground_truth = $this->gist_graph()->raw_data()->category_data()->summaries()->[ $url_data->index() ];
    
}

# should this model be serialized ?
sub serializable {

    my $that = shift;

    # Not serializable however the smoothing distributions should certainly be precomputed
    return 0;

}

no Moose;

1;
