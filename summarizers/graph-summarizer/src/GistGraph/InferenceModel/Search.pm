package GistGraph::InferenceModel::Search;

# Performs gist inference using a template-based approach

use strict;
use warnings;

use Moose;

use GistGraph::Gist;
use Similarity;

extends 'GistGraph::InferenceModel';

# run inference given a GistModel and a UrlData instance
sub run_inference {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;

    # run generation
    my $gist = $this->_generate( $gist_model , $url_data );

    return $gist;

}

# generate
sub _generate {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;

    # instantiate gist object
    my $gist = $gist_model->gist_graph()->get_blank_gist( $url_data->get_data()->{'url'} );

    # find ml path between the BOG node and the EOG node
    my $ml_path = $this->maximum_likelihood_path( $gist_model, $gist_model->gist_graph()->nodes()->{ $GistGraph::BOG_NODE_NAME } , $gist_model->gist_graph()->nodes()->{ $GistGraph::EOG_NODE_NAME } );

    # append path to our gist
    $gist->push_path( $ml_path );

    return $gist;

}

no Moose;

1;
