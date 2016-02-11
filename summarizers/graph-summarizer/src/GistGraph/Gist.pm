package GistGraph::Gist;

# Abstracts the notion of a gist within the gist-graph framework

use strict;
use warnings;

use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

# constant to indicate that an edge's verbalization is not fixed
our $GIST_EDGE_VERBALIZATION_NOT_SET_INDEX = 0;

# constant to indicate that a node's verbalization is not fixed
our $GIST_NODE_VERBALIZATION_NOT_SET_INDEX = 0;

# fields

# gist graph back-pointer
has 'gist_graph' => (is => 'ro', isa => 'GistGraph', required => 0, traits => ['DoNotSerialize']);

# path - i.e. ordered sequence of graph nodes - for the gist
has 'nodes' => (is => 'rw', isa => 'ArrayRef[GistGraph::Node]', default => sub { [] });

# node verbalization choices (currently that's the underlying chunk index)
has 'node_verbalizations' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

# ordered sequence of edges in this path
has 'edges' => (is => 'rw', isa => 'ArrayRef[GistGraph::Edge]', default => sub { [] });

# edge verbalization choices
has 'edge_verbalizations' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

# has been initialized
has 'initialized' => (is => 'rw', isa => 'Bool', default => 0);

# has been finalized
has 'finalized' => (is => 'rw', isa => 'Bool', default => 0);

# constructor
sub BUILD {

    my $this = shift;

    # Nothing for now

}

# push node
sub push_node {

    my $this = shift;
    my $node = shift;
    my $node_verbalization_index = shift;

    while ( scalar( @{ $this->nodes() } ) != scalar( @{ $this->edges() } ) ) {
	print STDERR "Pushing filling edge ...\n";
	$this->push_edge( undef );
    }

    if ( ! defined( $node_verbalization_index ) ) {
	$node_verbalization_index = $GIST_NODE_VERBALIZATION_NOT_SET_INDEX;
    }

    # TODO : check that this node isn't already in this gist's path ?
    push @{ $this->nodes() } , $node;
    push @{ $this->node_verbalizations() } , $node_verbalization_index;

}

# push edge
sub push_edge {

    my $this = shift;
    my $edge = shift;
    my $edge_verbalization_index = shift;

    if ( ! defined( $edge_verbalization_index ) ) {
	$edge_verbalization_index = $GIST_EDGE_VERBALIZATION_NOT_SET_INDEX;
    }

    push @{ $this->edges() } , $edge;
    push @{ $this->edge_verbalizations() } , $edge_verbalization_index;
    
}

# push path
sub push_path {

    my $this = shift;
    my $path = shift;

    foreach my $node (@{ $path }) {
	$this->push_node( $node );
    }

}

# get sequence of chunks for this gist
sub chunks {

    my $this = shift;
    my $include_edge_chunks = shift || 0;

    my @chunks;
    for (my $i=0; $i<scalar(@{ $this->nodes() }); $i++) {
	
	push @chunks, $this->node_verbalizations()->[ $i ];

	if ( $include_edge_chunks && ( scalar(@chunks) != scalar(@{ $this->nodes() }) ) ) {
	    push @chunks, $this->edge_verbalizations()->[ $i + 1 ];
	}

    }

    return \@chunks;

}

# get sequence lenght for this gist
sub length {

    my $this = shift;
    my $include_edge_chunks = shift || 0;

    my $length = scalar( @{ $this->nodes() } );

    return $length;

}

# access a give node
# TODO: is there a more Moose-friendly way of implementing this ?
sub get_node {

    my $this = shift;
    my $index = shift;

    return $this->nodes()->[ $index ];

}

# get the last node
sub get_last_node {

    my $this = shift;

    return $this->get_node( $this->length( 0 ) - 1 );

}

# initialize gist
sub initialize {

    my $this = shift;

    # we only initialize once
    if ( $this->initialized() ) {
	return;
    }

    # append BOG node
    $this->push_node( $this->gist_graph()->nodes()->{ $GistGraph::BOG_NODE_NAME } );

    # mark as initialized
    $this->initialized( 1 );

}

# finalize gist
sub finalize {

    my $this = shift;
    
    # we only finalize once
    if ( $this->finalized() ) {
	return;
    }

    # append EOG node
    $this->push_node( $this->gist_graph()->nodes()->{ $GistGraph::EOG_NODE_NAME } );

    # mark as finalized
    $this->finalized( 1 );

}

# linearize gist
sub linearize {

    my $this = shift;

    my @linearized_gist_components;
    my $length = $this->length();
    
    for (my $i=0; $i<$length; $i++) {

	my $current_node = $this->nodes()->[ $i ];

	push @linearized_gist_components, $current_node->verbalize( $this->node_verbalizations()->[ $i ] );
	if ( $i < $length - 1 ) {
	    my $next_node = $this->nodes()->[ $i + 1 ];
	    my $edge = $this->gist_graph()->get_verbalization_edge( $current_node , $next_node );
	    if ( ! $edge  ) {
		die "No edge exists between " . $current_node->id() . " and " . $next_node->id() . " ...\n";
	    }
	    push @linearized_gist_components, $edge->verbalize( $this->edge_verbalizations()->[ $i ] || 0 );
	}
	
    }

    return join(" ", @linearized_gist_components);

}

no Moose;

1;
