package Web::UrlData::Featurizer::DefaultFeaturizer;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# generate features for an instance
sub _run {

    my $this = shift;
    my $object = shift;
    my $feature_set = shift;

    # check cache first
    my $feature_set_key = md5_hex( $feature_set );
    if ( defined( $this->_featurized_cache->{ $feature_set_key } ) ) {
	return $this->_featurized_cache->{ $feature_set_key };
    }

    my $id_content = $this->url;
    my $data_entry = $this->get_data;
    my %generated_features;

    foreach my $modality ( @{ $this->modalities_ngrams } ) {

	my $modality_id = $modality->id;

	# filter modalities based on requested feature set
	if ( ! defined( $feature_set->{ $modality_id } ) ) {
	    next;
	}

	# TODO : add feature to indicate the presence of a modality

	my $modality_features = $feature_set->{ $modality_id };

	foreach my $modality_feature_type ( keys ( %{ $modality_features } ) ) {

	    my $modality_feature_type_params = $modality_features->{ $modality_feature_type };
	    my %local_features;

	    if ( $modality_feature_type eq $FIELD_MARKER_NGRAMS ) {

		# n-gram content features
		foreach my $ngram_order ( @{ $modality_feature_type_params } ) {
# CURRENT : problem seems to be here
		    my ( $modality_ngrams , $modality_data_mapping , $modality_data_mapping_surface ) = $this->get_modality_data( $modality , $ngram_order , 1 , 1 );
		    map { my $feature_key = _generate_feature_name( $modality_id , $ngram_order , $modality_data_mapping->{ $_ } ); $local_features{$feature_key} = $modality_ngrams->{$_}; } keys( %{ $modality_ngrams } );
		}

	    }
	    elsif ( $modality_feature_type eq 'node-context' ) {

		if ( $modality_feature_type_params ) { # make sure this type of feature is effectively turned on
		    my $nodes_appearance = $this->get_field( $modality , "appearance_context" );
		    map { my $feature_key = _generate_feature_name( $modality, $_); $local_features{$feature_key} = $nodes_appearance->{$_}; } keys( %{ $nodes_appearance } );
		}

	    }
	    else {
	    
		# include variations on all features as to whether it appears in title/body/link ?
		
		# expected POS
		# TODO
		#'word_expected_pos'

	    }

	    # updates features
	    # TODO: add check for conflicting features ? (DEBUG only)
	    map { $generated_features{$_} = $local_features{$_}; } grep { $local_features{$_} } keys( %local_features );
	    
	}

    }

    # update cache
    $this->_featurized_cache->{ $feature_set_key } = \%generated_features;

    # CURRENT : test for loop in generated_features
    
    # return feature vector
    return \%generated_features;
    
}

__PACKAGE__->meta->make_immutable;

1;
