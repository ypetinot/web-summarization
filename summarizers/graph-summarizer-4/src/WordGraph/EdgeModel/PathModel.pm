package WordGraph::EdgeModel::PathModel;

# Generates individual edge-costs for a word-graph based on known (energy) costs for the paths used in its contruction

use strict;
use warnings;

use File::Temp qw/ tempfile /;
use List::Util qw/max min/;
use Memoize;
use Path::Class;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with('WordGraph::EdgeModel');

# edge assignment mode
our $ASSIGNMENT_MODE_ADD="add";
our $ASSIGNMENT_MODE_MIN="min";
our $ASSIGNMENT_MODE_MAX="max";
has 'assignment_mode' => ( is => 'ro' , isa => enum([$ASSIGNMENT_MODE_ADD,$ASSIGNMENT_MODE_MIN,$ASSIGNMENT_MODE_MAX]) , default => $ASSIGNMENT_MODE_ADD );


=pod
# local cost store (disconnected from both EdgeCost or WordGraph)
has '_cost_store' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '__cost_store_builder' );
sub __cost_store_builder {
    
}
=cut

sub _local_edge_key {

    my $this = shift;
    my $edge = shift;

    # TODO : allow dependence on target intance ?
    my $edge_key = join( "::" , @{ $edge } );

    return $edge_key;

}

memoize('_compute_all_weights');
sub _compute_all_weights {

    my $this = shift;
    my $graph = shift;
    
    my %weights;

    foreach my $graph_path_label (keys %{ $graph->paths() }) {
	
	my $graph_path = $graph->paths()->{ $graph_path_label };
	my $graph_path_energy = $graph->paths2energy()->{ $graph_path_label };
	
	my $graph_path_length = $graph_path->length();
	my $graph_path_energy_quantum = $graph_path_energy / $graph_path_length;
	    
	my @path_edge_ids;
	my $previous_node = undef;
	for (my $i=0; $i<$graph_path_length; $i++) {
	    
	    my $current_node = $graph_path->get_element( $i );	    
	    if ( $i ) {

		my $current_edge = [ $previous_node , $current_node ];

		# TODO : allow dependence on target intance ?
		my $current_edge_key = $this->_local_edge_key( $current_edge );

		my $current_weight = $weights{ $current_edge_key } || 0 ;
		my $updated_weight;
		
		if ( $this->assignment_mode() eq $ASSIGNMENT_MODE_ADD ) {
		    $updated_weight = $current_weight + $graph_path_energy_quantum;
		}
		elsif( $this->assignment_mode() eq $ASSIGNMENT_MODE_MIN ) {
		    $updated_weight = min( $current_weight , $graph_path_energy_quantum );
		}
		elsif ( $this->assignment_mode() eq $ASSIGNMENT_MODE_MAX ) {
		    $updated_weight = max( $current_weight , $graph_path_energy_quantum );
		}
		else {
		    die "Unsupported mode: " . $this->assignment_mode();
		}

		# update weight
		$weights{ $current_edge_key } = $updated_weight;
		
	    }
	    
	    $previous_node = $current_node;
	    
	}
	
    }

    return \%weights;

}

# compute edge weights
# TODO : might still require some more work to normalize relation with EdgeCost ...
sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift; # Note : exceptionally here we generate all edge weights in one shot (should we add an attribute to store these value and make things cleaner ?)
    my $edge_features = shift;
    my $instance = shift;

    # TODO : ...
    my $edge_key = $this->_local_edge_key( $edge );

    #return $this->_cost_store->{ $edge_key };
    return $this->_compute_all_weights( $graph )->{ $edge_key };

}

__PACKAGE__->meta->make_immutable;

1;
