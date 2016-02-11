package WordGraph::EdgeModel;

# EdgeModel combines edge features and edge feature weights into a single edge weight
# Edge features may be conditioned on the target instance and thus any caching operation must take into account the target instance begin considered

use strict;
use warnings;

my $DEBUG = 0;

use WordGraph::Path;

#use Moose;
use Moose::Role;
#use namespace::autoclean;

# CURRENT: does not seem necessary, Model would be sufficient ... why ?
with('ReferenceTargetModel');

=pod
# cost cache
# TODO : is there a better way to do this ? in particular I would like a solution to "build" individual entries in this hash
has 'cost_cache' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );
=cut

=pod
sub edge_cost_key {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;

    # TODO : can we clean this up (->[ 0 ]) ?
    my $edge_cost_key = join( '-' , $graph , @{ $edge } , $instance->[ 0 ]->id );

    return $edge_cost_key;

}
=cut

# update specific feature weight
# TODO: is there a more Moosian way of generating this method
sub update_feature_weight {

    my $this = shift;
    my $feature_id = shift;
    my $feature_updated_value = shift;

    print STDERR "Updating feature weight for $feature_id => $feature_updated_value\n";

    $this->feature_weights()->{ $feature_id } = $feature_updated_value;

}

sub compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift; # needed ?

    # 1 - retrieve features for the target edge
    my $edge_features = $this->compute_edge_features( $instance , $edge , $graph );

    # 2 - run actual cost(s) computation
    my $edge_cost = $this->_compute( $graph , $edge , $edge_features , $instance );
	    
    $this->trace( join( "\t" , "Edge cost" , $instance->[ 0 ]->id() , $edge->[ 0 ] , $edge->[ 1 ] ,
			   join( " " , map { $_ . ":" . $edge_features->{ $_ } } keys( %{ $edge_features } ) ) ,
			   $edge_cost ) );

    return $edge_cost;
    
}

# compute feature vector for a given edge
sub compute_edge_features {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    # Are edge features conditioned on the target instance (instead of just the path) ? --> potentially yes !

    my %edge_features;

    # Iterate over edge feature definitions
    foreach my $feature_id ( keys %{ $this->features } ) {
	my $feature_definition = $this->features->{ $feature_id };
	my $feature_values = $feature_definition->compute_cached( $instance->[ 0 ] , $edge , $graph );
	map { $edge_features{ $_ } = $feature_values->{ $_ }; } keys( %{ $feature_values } );
    }

    # add slot features (for either/both the edge source and sink if they are slots)
    for (my $i=0; $i<=1; $i++) {
       
	# TODO: we should probably add a structural constraint that two slots cannot follow each other (actually this might already be the case)

	my $node = $edge->[ $i ];
	# TODO: if we turn edges into a class, we can create a role 'Featurizable' so that all nodes can be associated with a set of features
	# (by default empty for regular nodes)
	if ( ref( $node ) eq 'WordGraph::Node::Slot' ) {
	    
	    my $filler_features = $node->get_filler_features( $instance );
	    map { $edge_features{ $_ } = $filler_features->{ $_ } } keys( %{ $filler_features } );

	}

    }

    return \%edge_features;

}

sub create_instance {

    # Note : here an instance is just a WordGraph::Path

    my $this = shift;
    my $graph = shift;
    my $instance_raw = shift;
    my $instances_dev = shift;

    return new WordGraph::Path( graph => $graph , node_sequence => [] , object => $instance_raw->[ 0 ] );

}

sub featurize {

    my $this = shift;
    my $graph = shift;
    my $instance_in = shift;
    my $instance_out = shift;

    # Note (again) that we are training an edge model here, so instance_out is always going to be a path in the word-graph
    # In other words we simply follow the path and add each edge's features

    return $this->_compute_path_features( $graph , $instance_in , $instance_out );

}
        
# combine/intersect full input features with current path
sub _compute_path_features {
    
    my $this = shift;
    my $graph = shift;
    my $instance_in = shift;
    my $path = shift;
    
    my $features = {};
    
    # Loop over edges that are present in $path --> all other edge features are therefore/implicitly forced to be 0
    for (my $i=0; $i<scalar(@{ $path }) - 1; $i++) {
	
	my $from = $path->[ $i ];
	my $to = $path->[ $i + 1 ];
	
	my $current_edge = [ $from , $to ];
	# TODO : add check to see whether the model requires the reference set to be passed (could be done at a higher level actually).
	my $edge_features = $this->compute_edge_features( ( $this->does( 'ReferenceTargetModel') ? $instance_in : $instance_in->[ 0 ] ), $current_edge , $graph );
	
	map { $features->{ $_ } = $edge_features->{ $_ }; } keys( %{ $edge_features } );
	
    }
    
    return $features;
    
}

# TODO : how do we turn this into a probability metric ?
sub cost {

    my $this = shift;
    my $instance_in = shift;
    my $instance_out = shift;

    my $cost = 0;
    my $graph = undef;

    my $instance_out_length = $instance_out->length;
    if ( $instance_out_length > 1 ) {
	for (my $i=0; $i<$instance_out_length- 1; $i++) {
	    my $edge = [ $instance_out->[ $i ] , $instance_out->[ $i + 1 ] ];
	    $cost += $this->compute( $graph , $edge , $instance_in );
	}
    }

    return $cost;

}

#__PACKAGE__->meta->make_immutable;

1;
