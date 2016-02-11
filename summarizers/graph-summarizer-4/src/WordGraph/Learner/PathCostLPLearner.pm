package WordGraph::Learner::PathCostLearner;

use strict;
use warnings;

use File::Temp qw/ tempfile /;

use Moose;
use namespace::autoclean;

extends 'WordGraph::Learner';

# compute weights
sub _compute_weights {

    my $this = shift;

    # 1 - generate LP problem
    my $lp_problem_fh = File::Temp->new();
    my $lp_problem_filename = $lp_problem_fh->filename;
    my $edge_weight_mapping = $this->generate_lp_problem( $lp_problem_filename );

    # 2 - run LP solver
    my $lp_solution = $this->run_lp_solver( $lp_problem_filename );

    # 3 - map weights
    # TODO
    my %weights;

    return \%weights;

}

# generate LP problem for the associated graph/paths
sub generate_lp_problem {

    my $this = shift;
    my $lp_filename = shift;

    # TODO: should these mapping be maintained by WordGraph
    my %edge2id;
    my %id2edge;

    # one equation per path in the graph
    my @lp_data;
    foreach my $graph_path_label (keys %{ $this->graph->paths }) {

	my $graph_path = $this->graph->paths->{ $graph_path_label };
	my $graph_path_energy = $this->graph->paths2energy->{ $graph_path_label };

	my $graph_path_length = $graph_path->length;

	my @path_edge_ids;
	my $previous_node = undef;
	for (my $i=0; $i<$graph_path_length; $i++) {
	   
	    my $current_node = $graph_path->get_element( $i );

	    if ( $i ) {
		
		my $edge = [ $previous_node , $current_node ];
		my $edge_key = join( " " , @{ $edge } );
		if ( ! defined( $edge2id{ $edge_key } ) ) {
		    my $edge_id = "e" . ( scalar( keys( %edge2id ) ) + 1 );
		    print STDERR ">> $edge_id : $previous_node --> $current_node\n";
		    $edge2id{ $edge_key } = $edge_id;
		    $id2edge{ $edge_id  } = $edge;
		}
		
		push @path_edge_ids, $edge2id{ $edge_key };

	    }

	    $previous_node = $current_node;

	}

	push @lp_data , [ \@path_edge_ids , $graph_path_energy ];

    }
    
    # write lp problem to file
    # TODO: create class to manipulate LP programs / MathProg ... how ?

    open LP_PROBLEM , ">$lp_filename" or die "Unable to create lp problem file ($lp_filename): $!";
    
    print LP_PROBLEM "\\* graph edge-energy lp *\\\n\n";
#    print LP_PROBLEM "Minimize\n";
    print LP_PROBLEM "Maximize\n";
    print LP_PROBLEM "graph_energy: " . join( " + " , keys( %id2edge ) ) . "\n\n";
    print LP_PROBLEM "Subject To\n";
    
    for (my $i=0; $i<scalar(@lp_data); $i++) {

	my $lp_data_entry = $lp_data[ $i ];
	my $path_edges = $lp_data_entry->[ 0 ];
	my $path_energy = $lp_data_entry->[ 1 ];

	my $path_id = "path_$i";

	#print LP_PROBLEM "${path_id}: " . join( " + " , @{ $path_edges } ) . " = ${path_energy}\n";
	print LP_PROBLEM "${path_id}: " . join( " * " , @{ $path_edges } ) . " = ${path_energy}\n";

    }

=pod
    map {
	print LP_PROBLEM "non_zero_${_}: $_ > 0.1\n";
    } keys( %id2edge );
=cut

    print LP_PROBLEM "Bounds\n";
    print LP_PROBLEM "\n";

    print LP_PROBLEM "End\n";

    close LP_PROBLEM;

    return \%id2edge;

}

with( 'LPSolver' );

__PACKAGE__->meta->make_immutable;

1;
