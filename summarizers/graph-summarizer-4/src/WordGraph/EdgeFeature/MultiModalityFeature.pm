package WordGraph::EdgeFeature::MultiModalityFeature;

use Moose;
use namespace::autoclean;

extends 'WordGraph::EdgeFeature';

# Note : removing for now
=pod
# target modalities
has 'modalities' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );
=cut

# aggregate
has 'aggregate' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# feature key
sub key {

    my $this = shift;
    my $domain = shift;

    return $this->SUPER::key( $domain , "multi-modalities" , @_ );

}

# post process / aggregate
sub post_process {

    my $this = shift;
    my $features = shift;

    my %post_processed_features = %{ $features };

    if ( $this->aggregate() ) {

	my %aggregates;
	my $n_modalities = 0;

	foreach my $modality (keys( %{ $features } )) {
	    
	    my $modality_features = $features->{ $modality };
	    
	    if ( ref( $modality_features ) ){
		
		foreach my $modality_feature (keys ( %{ $modality_features } )) {
		    
		    my $modality_feature_value = $modality_features->{ $modality_feature };
		    
		    # no matter what, we copy the current feature
		    $post_processed_features{ 'aggregate' }{ $modality_feature } += $modality_feature_value;
		    
		}
		
	    }
	    else {
		
		# no matter what, we copy the current feature
		$post_processed_features{ 'aggregate' } += $modality_features;

	    }
	    
	    $n_modalities++;
	    
	}

	if ( ref(  $post_processed_features{ 'aggregate' } ) ) {
	    map { $post_processed_features{ 'aggregate' }{ $_ } /= $n_modalities; } keys( %{ $post_processed_features{ 'aggregate' } } );
	}
	else {
	    $post_processed_features{ 'aggregate' } /= $n_modalities;
	}
	
    }

    return \%post_processed_features;

}

# get_resources
sub get_resources {
    
    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;

    my %resources;
    foreach my $modality (@{ $this->modalities }) {
	$resources{ $modality } = $this->_get_resources( $graph , $edge , $instance , $modality );
    }

    return \%resources;

}

# value node
sub value_node {
    
    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;

    my %modality2features;
    foreach my $modality (@{ $this->modalities }) {

	my $modality_feature_value = $this->_value_node( $graph , $edge , $instance , $common_resources , $node_index , $modality );
	$modality2features{ $modality } = $modality_feature_value;

    }

    return $this->post_process( \%modality2features );

}

# value edge
sub value_edge {
    
    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $source_features = shift;
    my $sink_features = shift;
    
    my %modality2features;
    foreach my $modality (@{ $this->modalities }) {

	my $modality_feature_value = $this->_value_edge( $graph , $edge , $instance , $common_resources , $source_features , $sink_features , $modality );
	if ( ref( $modality_feature_value ) ) {
	    foreach my $feature_key (keys( %{ $modality_feature_value })) {
		$modality2features{ join( "::" , $modality , $feature_key ) } = $modality_feature_value->{ $feature_key };
	    }
	}
	else {
	    $modality2features{ $modality } = $modality_feature_value;
	}

    }

    return $this->post_process( \%modality2features );

}

__PACKAGE__->meta->make_immutable;

1;
