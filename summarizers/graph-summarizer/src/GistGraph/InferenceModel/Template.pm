package GistGraph::InferenceModel::Template;

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

    # 1 - select base gist
    my $base_gist_id = $this->_select_base_gist( $this->mode() , $gist_model , $url_data );

    # 2 - run generation following the template defined by the base gist
    my $gist = $this->_generate( $gist_model , $url_data , $base_gist_id );

    return $gist;

}

# select base gist
sub _select_base_gist {

    my $this = shift;
    my $mode = shift;
    my $gist_model = shift;
    my $url_data = shift;

    my $training_gist_count = $gist_model->gist_graph()->get_gists_count();
    my $selected_gist_id = undef;

    if ( $mode eq 'random' ) {

	$selected_gist_id = int( rand( $training_gist_count ) );

    }
    elsif ( $mode eq 'centroid' ) {

	my %centroid;

	# 1 - compute centroid of all training gists in the node-space
	for (my $i=0; $i<$training_gist_count; $i++) {
	    
	    my $current_gist = $gist_model->gist_graph()->get_gist( $i );
	    foreach my $node ( @{ $current_gist->nodes() } ) {
		$centroid{ $node->id() } ++;
	    }

	}

	# 2 - compute distance of all training gists to the centroid
	my $closest_gist_similarity = -1;
	my $closest_gist_id = undef;
	for (my $i=0; $i<$training_gist_count; $i++) {

	    my $current_gist = $gist_model->gist_graph()->get_gist( $i );
	    my %current_gist_vector;
	    map { $current_gist_vector{ $_->id() }++; } @{ $current_gist->nodes() };
	    
	    my $gist_centroid_similarity = Similarity::_compute_cosine_similarity( \%centroid , \%current_gist_vector );

	    if ( $gist_centroid_similarity > $closest_gist_similarity ) {
		$closest_gist_similarity = $gist_centroid_similarity;
		$closest_gist_id = $i;
	    }

	}

	# 3 - select training gist that is closest to the centroid
	$selected_gist_id = $closest_gist_id;

    }
    elsif ( $mode eq 'overlap' ) {

	my $target_object_content = $url_data->get_data()->{ 'content::prepared' };
	my %target_object_content_vector;
	map { $target_object_content_vector{ $_ }++ } @{ $target_object_content };

	my $closest_gist_similarity = -1;
	my $closest_gist_id = undef;
	for (my $i=0; $i<$training_gist_count; $i++) {

	    my $current_gist = $gist_model->gist_graph()->get_gist( $i );
	    my %current_gist_vector;
	    map { $current_gist_vector{ $_ }++; } @{ $current_gist->chunks( 0 ) };

	    # TODO: are both vectors in similar space / properly abstracted ?
	    my $gist_object_similarity = Similarity::_compute_cosine_similarity( \%target_object_content_vector , \%current_gist_vector );

	    if ( $gist_object_similarity > $closest_gist_similarity ) {
		$closest_gist_similarity = $gist_object_similarity;
		$closest_gist_id = $i;
	    }

	}

	$selected_gist_id = $closest_gist_id;

    }
    else {
	print STDERR "Unsupported inference mode: $mode\n";
    }

    return $selected_gist_id;

}

# generate
sub _generate {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;
    my $base_gist_id = shift;

    # instantiate gist object
    my $gist = $gist_model->gist_graph()->get_blank_gist( $url_data->get_data()->{'url'} );

    # fetch gist object for base gist
    my $base_gist = $gist_model->gist_graph()->get_gist( $base_gist_id );

    # generate new gist using base gist as "template"
    my $i = 0;
    while ( $i < $base_gist->length() ) {

	# current node
	my $current_node = $base_gist->get_node( $i++ );
	my $current_node_appearance_probability = $gist_model->np_appearance_model()->get_probability( $current_node );

	if ( $current_node_appearance_probability > 1 - $current_node_appearance_probability ) {
	    $gist->push_node( $current_node );
	}
	else {

	    # Note: we're guaranteed to reach the EOG node eventually,
	    # although node smoothing is probably a desirable property for any appearance model to have (?)
	    while ( ( $current_node_appearance_probability <= 1 - $current_node_appearance_probability ) &&
		    ( $i < $base_gist->length() - 1 )
		) {
		$current_node = $base_gist->get_node( $i++ );
		$current_node_appearance_probability = $gist_model->np_appearance_model()->get_probability( $current_node );
	    }
	    my $ml_path = $this->maximum_likelihood_path( $gist_model, $gist->get_last_node(), $base_gist->get_node( $i++ ) );

	    # clip out the first node ( which we already have )
	    if ( scalar( @{ $ml_path } ) ) {
		shift @{ $ml_path };
	    }

	    # append path to our gist
	    $gist->push_path( $ml_path );
	    
	}

    }

    return $gist;

}

no Moose;

1;
