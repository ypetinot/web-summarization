package GistGraph;

# implementation of the gist-graph

# The gist graph is simply an abstraction over the raw category data
# --> this way we can define multiple versions of the graph while keeping the same underlying raw data (i.e. useful for folds)
# directed graph to preserve minimal ordering information, but the graph should also be viewable as an undirected graph for RF sub-models

# (Principled clustering) Energy-based clustering:
# --> cannot-link contraints should lead to high energy when broken
# --> high similarity pairs should lead to high energy when not linked
# Minimization task (need to figure out representation and optimization tool to be used)

# (Hierarchical clustering) 

# Approaches for similarity function:
# 1 - weighted average of contributing similarity functions (surface,context,semantics) - no parameter learning
# 2 - weighted average of contributing similarity functions, with learning of weights based on link/cannot-link constraints
# 3 - fully-parameterized similarity function, with learning of parameters based on link/cannot-link constraints

use Moose;
use MooseX::Storage;

use Category::Data;
use Category::Fold;
use Clusterer::Hierarchical;
use GistGraph::Gist;
use GistGraph::Node;
use GistGraph::Node::Context;
use GistGraph::Edge;
use GistGraph::Edge::Verbalization;
use NPMatcher;

use File::Path;
use List::Util qw/min max/;
use Statistics::Descriptive;

our $DEBUG = 1;

# id for the Beginning Of Gist node  
our $BOG_NODE_NAME = 'bog';

# id for the End Of Gist node
our $EOG_NODE_NAME = 'eog';

# flag name for generic nodes
our $FLAG_GENERIC = 'generic';

# flag name for specific nodes
our $FLAG_SPECIFIC = 'specific';

# gist graph serialization file
our $GIST_GRAPH_SERIALIZATION_FILENAME = "gist_graph.json";

with Storage('format' => 'JSON', 'io' => 'File');

# ********************************************************************************* #
# fields 

# root directory for all model files
has 'model_directory' => (is => 'ro', isa => 'Str', required => 1);

# raw data (implicitly specified through the model directory path)
# ( it is important to keep a relative path to the category (fold) data since the content of the graph depends on it ) 
has 'raw_data' => (is => 'rw', isa => 'Category::Data', required => 0, init_arg => 'category_data', traits => [ 'DoNotSerialize' ]);

# fold id based on which this graph was generated - used to reload fold data later on
has 'fold_id' => (is => 'rw', isa => 'Str'); 

# nodes in the graph are stored in an array
# the first 2 nodes are the Beginning of Gist and End of Gist nodes
has 'nodes' => (is => 'rw', isa => 'HashRef[GistGraph::Node]', default => sub { {} });

# edges between nodes are indexed by an edge key
has 'edges' => (is => 'rw', isa => 'HashRef[GistGraph::Edge]', default => sub { {} });

# verbalization edges
has 'verbalization_edges' => (is => 'rw', isa => 'HashRef[GistGraph::Edge]', default => sub { {} });

# context representation for this node
has 'contexts' => (is => 'ro', isa => 'HashRef[GistGraph::Node::Context]', default => sub { {} });
#, traits => [ 'DoNotSerialize' ]);

# maps a raw chunk to its associated node
# (could be recomputed if needed)
has 'chunk2node' => (is  => 'rw', isa => 'HashRef', default => sub { {} });
#, traits => [ 'DoNotSerialize' ] );

# training gists
has 'gists' => (is => 'rw', isa => 'ArrayRef[GistGraph::Gist]', lazy => 1, init_arg => undef, builder => '_build_gists', traits => [ 'DoNotSerialize' ]);

# plotting on/off
has 'do_plotting' => (is => 'rw', isa => 'Num', default => 0, traits => [ 'DoNotSerialize' ]);

# ********************************************************************************* #

# constructor
sub BUILD {

    my $this = shift;
    my $args = shift;

}

# init
sub init {

    my $this = shift;

    # keep track of what fold was used to generate this graph
    $this->fold_id( $this->raw_data()->id() );

    return $this;

}

# serialization file
sub serialization_file {

    my $that = shift;
    my $model_root = shift;

    if ( ref( $that ) && ! defined( $model_root ) ) {
	$model_root = $that->model_root();
    }

    return join("/", $model_root, $GIST_GRAPH_SERIALIZATION_FILENAME);

} 

# write out to file
sub write_out {

    my $this = shift;
    my $filename = shift;

    $this->store($filename);

}

# load a serialized gist graph
sub restore {

    my $that = shift;
    my $raw_data = shift;
    my $model_root = shift;
    my $check_integrity = shift || 0;

    my $serialization_file = $that->serialization_file( $model_root );
    my $gist_graph = undef;

    if ( -f $serialization_file ) {

	print STDERR "Restoring gist graph from $model_root ...\n";
	
	# load gist graph from file
	$gist_graph = __PACKAGE__->load( $that->serialization_file( $model_root ) );

	# locate raw data location and set back-pointer(s)
	# TODO: should setting the raw data automatically propagate to all nodes/edges
	$gist_graph->raw_data( $raw_data );
	
	# set node back pointers
	my @nodes = values( %{ $gist_graph->nodes() } );
	foreach my $node (@nodes) {
	    $node->raw_data( $gist_graph->raw_data() );
	}
	
	# set edges back pointers
	my @edges = values( %{ $gist_graph->edges() } );
	foreach my $edge (@edges) {
	    $edge->gist_graph( $gist_graph );
	}
	
	# set verbalization edges back pointers
	my @verbalization_edges = values( %{ $gist_graph->verbalization_edges() } );
	foreach my $edge (@verbalization_edges) {
	    $edge->gist_graph( $gist_graph );
	}
	
	# make sure the gist graph has not been corrupted
	if ( $check_integrity ) {
	    if ( ! $gist_graph->check_integrity() ) {
		#die "Integrity check failed ...";
		print STDERR "Serialized gist graph is corrupted, unable to load ...\n";
		$gist_graph = undef;
	    }
	}

    }
    else {

	print STDERR "No serialized gist graph found ...\n";

    }

    return $gist_graph;

}

# get node given a chunk id
sub get_node_for_chunk {

    my $this = shift;
    my $chunk_id = shift;

    my $node_id = $this->chunk2node()->{ $chunk_id };
    if ( defined($node_id) ) {
	return $this->nodes()->{ $node_id };
    }

    return undef;

}

# get_nodes
sub get_nodes {

    my $this = shift;

    my @nodes = values( %{ $this->nodes() } );
    return \@nodes;

}

# delete a node
sub delete_node {

    my $this = shift;
    my $node = shift;

    my $node_resolved = $this->_map_to_node_ref( $node );
    
    # delete node
    delete( $this->nodes()->{ $node_resolved->id() } );

    # delete underlying chunks / verify here ?
    # TODO

    return $node_resolved;

}

# map a node id to the underlying Node instance / no-op for Node instances
sub _map_to_node_ref {

    my $this = shift;
    my $node_var = shift;

    if ( ! defined( $node_var ) ) {
	print STDERR "Requesting node mapping for undefined node id ...";
	return undef;
    }

    # TODO: we could also check that this is indeed a GistGraph::Node reference
    if ( ref( $node_var ) ) {
	return $node_var;
    }

    # TODO: should we have a hash mapping for this ?
    my $selected_nodes = $this->node_filter( sub { my $node = shift; return ( $node->id() eq "$node_var" ); } );
    if ( scalar(@{ $selected_nodes }) > 1 ) {
	die "Problem: found more than one node with id $node_var";
    }
    elsif ( scalar(@{ $selected_nodes }) != 1 ) {
	return undef;
    }

    return $selected_nodes->[0];

}

# underlying edge getter
sub _get_edge {

    my $this = shift;
    my $node_a = shift;
    my $node_b = shift;
    my $edge_type = shift;

    my $node_a_resolved = $this->_map_to_node_ref( $node_a );
    my $node_b_resolved = $this->_map_to_node_ref( $node_b );

    if ( ! defined($node_a_resolved) || ! defined($node_b_resolved) ) {
	print STDERR "Invalid node provided in get_edge ...\n";
    }

    # 1 - determine edge key
    my $edge_key = $this->_edge_key($node_a_resolved,$node_b_resolved,$edge_type);

    my $edge = undef;

    # 2 - fetch edge instance (if there is one associated with this edge key)
    if ( $edge_type == 0 ) {	
	$edge = $this->edges()->{ $edge_key };
    }
    else {	
	$edge = $this->verbalization_edges()->{ $edge_key };
    }

    return $edge;

}


# verbalization edge getter between a given pair of nodes
sub get_verbalization_edge {

    my $this = shift;
    my $node_a = shift;
    my $node_b = shift;

    return $this->_get_edge($node_a,$node_b,1);

}

# edge getter given a pair of nodes
sub get_edge {

    my $this = shift;
    my $node_a = shift;
    my $node_b = shift;

    return $this->_get_edge($node_a,$node_b,0);

}

# create/update edge
sub create_or_update_edge {

    my $this = shift;
    my $node_a = shift;
    my $node_b = shift;
    my $gist_id = shift;
    my $verbalization = shift;
    my $distance = shift || 0;

    if ( !defined($node_a) || !defined($node_b) || !defined($gist_id) || !defined($verbalization) ) {
	die "Invalid arguments for create_or_update_edge: $node_a / $node_b / $gist_id / $verbalization ...";
    }

    # 0 - determine edge key
    my $edge_key = $this->_edge_key($node_a,$node_b,0);
    my $directed_edge_key = $this->_edge_key($node_a,$node_b,1);

    # 1 - make sure no edge already exists between these two nodes
    my $current_edge = $this->edges()->{ $edge_key };
    my $current_directed_edge = $this->verbalization_edges()->{ $directed_edge_key };

    # 2 - create edge if necessary
    if ( ! defined( $current_edge ) ) {

	# instrantiate edge
	$current_edge = new GistGraph::Edge( gist_graph => $this , from => $node_a->id() , to => $node_b->id() );

	# register edge with the gist graph
	$this->edges()->{ $edge_key } = $current_edge;

    }
    $current_edge->add_occurrence( $gist_id , $distance );

    # 3 - add verbalization to this edge
    # TODO: ideally, if the chunking is right, we should never have a "blank" verbalization (i.e. two NPs cannot simply be adjacent, without anything linking them)
    # (why ? because the link indicates the relationship between the two NPs - what about "." ?)
    if ( ! $distance ) {

	if ( ! defined( $current_directed_edge ) ) {
	    
	    # instantiate directed edge
	    $current_directed_edge = new GistGraph::Edge::Verbalization( gist_graph => $this , from => $node_a->id() , to => $node_b->id() );
	    
	    # register verbalization edge with the gist graph
	    $this->verbalization_edges()->{ $directed_edge_key } = $current_directed_edge;

	}

	# add new verbalization to this verbalization edge
	$current_directed_edge->add_verbalization( $verbalization );

    }
    
    return $current_edge;

}

# compute edge key
sub _edge_key {

    my $this = shift;

    # TODO: map node to id instead
    my $node_from = $this->_map_to_node_ref( shift );
    my $node_to = $this->_map_to_node_ref( shift );

    my $directed = shift || 0; 

    if ( ! defined($node_from) || ! defined($node_from) ) {
	print STDERR "Invalid node provided in _edge_key ...\n";
    }

    my @ids = ( $node_from->id() , $node_to->id() );

    if ( ! $directed ) {
	@ids = sort { $a cmp $b } ( $node_from->id() , $node_to->id() );
    }

    return join("-", @ids);

}

# get all np nodes in this graph
sub get_np_nodes {

    my $this = shift;

    my @np_nodes;

    my $nodes = values( %{ $this->nodes() } );
    foreach my $node (@$nodes) {
	if ( $node->is_np() ) {
	    push @np_nodes, $node;
	}
    }

    return \@np_nodes;

}

# method to determine the number of occurrence of a particular NP in the training set
sub get_count {

    my $this = shift;
    my $node = shift;

    # TODO: add (argument) adapter so that either a node id or a node ref can be passed

    my $count = 0;

    my $training_summaries = $this->summaries();
    foreach my $training_summary (@{ $training_summaries }) {
	foreach my $training_summary_node_id (@{ $training_summary }) {
	    if ( $node->same_as( $training_summary_node_id ) ) {
		$count++;
		last;
	    }
	}
    }
	
    return $count;

}

# get all regular nodes
sub get_regular_nodes {

    my $this = shift;

    return $this->node_filter( sub { 1; }, 0 );

}

# get all special nodes
sub get_special_nodes {

    my $this = shift;

    my @special_nodes;
    push @special_nodes, $this->nodes()->{ $BOG_NODE_NAME };
    push @special_nodes, $this->nodes()->{ $EOG_NODE_NAME };

    return \@special_nodes;

}

sub merge_nodes {

    my $this = shift;
    my $nodes = shift;
    my $justification = shift;

    my @nodes_to_merge = @{ $nodes };
    my $node_1 = shift @nodes_to_merge;

    while ( scalar( @nodes_to_merge ) ) {

	my $node_2 = shift @nodes_to_merge;    

	if ( $DEBUG && ! $this->check_integrity() ) {
	    die "Gist graph is invalid during before merging $node_1 and $node_2 ...";
	}
	
	# merge node 2 into node 1
	$node_1->merge($node_2,$justification);
	
	my $new_node_id = $node_1->id();
	my $old_node_id = $node_2->id();
	
	foreach my $edge_mode ( (0,1) ) {
	    
	    my @edges_set;
	    if ( $edge_mode == 0 ) {
		@edges_set = keys( %{ $this->edges() } );
	    }
	    else {
		@edges_set = keys( %{ $this->verbalization_edges() } );
	    }
	    
	    foreach my $edge_key ( @edges_set ) {
		
		my $from_node_id = undef;
		my $to_node_id = undef;
		
		# TODO: can we make this more portable, i.e. by going through _edge_key ?
		if ( $edge_key =~ m/^${old_node_id}-${old_node_id}$/ ) {
		    $from_node_id = $new_node_id;
		    $to_node_id   = $new_node_id;
		}
		elsif ( $edge_key =~ m/^${old_node_id}-(.+)$/ ) {
		    $from_node_id = $new_node_id;
		    $to_node_id   = $1;
		}
		elsif ( $edge_key =~ m/^(.+)-${old_node_id}$/ ) {
		    $from_node_id = $1;
		    $to_node_id   = $new_node_id;
		}
		else {
		    # nothing to do for this one
		    next;
		}
		
		if ( $DEBUG ) {
		    print STDERR "[merge_nodes] found matching edge ($edge_key): from ( $from_node_id ) / to ( $to_node_id )\n";
		}
		
		my $edge = undef;
		my $existing_edge = undef;
		
		if ( $edge_mode == 0 ) {
		    $edge = $this->edges()->{ $edge_key };
		    $existing_edge = $this->get_edge( $from_node_id , $to_node_id );
		}
		else {
		    $edge = $this->verbalization_edges()->{ $edge_key };
		    $existing_edge = $this->get_verbalization_edge( $from_node_id , $to_node_id );
		}
		
		# check wether an edge exists when the old node is replaced with the new node
		if ( defined( $existing_edge ) ) {
		    
		    # we need to merge the two edges
		    $existing_edge->merge( $edge );
		    if ( $DEBUG ) {
			print STDERR "[merge_nodes] merging edges ...\n";
		    }
		
		}
		else {
		    
		    # we simply copy the current entry
		    my $new_edge_key = $this->_edge_key( $from_node_id , $to_node_id , $edge_mode );
		    
		    # we update the old edge's source and destination
		    $edge->from( $from_node_id );
		    $edge->to( $to_node_id );
		    
		    # create the edge entry
		    if ( $edge_mode == 0 ) {
			$this->edges()->{ $new_edge_key } = $edge;
			if ( $DEBUG ) {
			    print STDERR "[merge_nodes] creating new undirected edge $new_edge_key ...\n";
			}
		    }
		    else {
			$this->verbalization_edges()->{ $new_edge_key } = $edge;
			if ( $DEBUG ) {
			    print STDERR "[merge_nodes] creating new directed edge $new_edge_key ...\n";
			}
		    }
		    
		}
		
		# remove old edge
		if ( $edge_mode == 0 ) {
		    delete $this->edges()->{ $edge_key };
		    if ( $DEBUG ) {
			print STDERR "[merge_nodes] deleting undirected edge $edge_key ...\n";
		    }
		}
		else {
		    delete $this->verbalization_edges()->{ $edge_key };
		    if ( $DEBUG ) {
			print STDERR "[merge_nodes] deleting directed edge $edge_key ...\n";
		    }
		}
		
	    }
	    
	}
	
	# update chunk to node mapping for the old node
	my @temp_chunks = @{ $node_2->raw_chunks() };
	foreach my $temp_chunk (@temp_chunks) {
	    $this->chunk2node()->{ $temp_chunk } = $node_1->id();
	}
	
	# finally completely remove node_2
	$this->delete_node( $node_2 );
	
	if ( $DEBUG && ! $this->check_integrity() ) {
	    die "Gist graph is invalid after merging " . $node_1->id() . " and " . $node_2->id() . " ...";
	}

    }
	
}

# merge cluster sets
sub _merge_cluster_sets {

    my $this = shift;
    my $cluster_sets = shift;
    my $justification = shift;

    my @merged_clusters;
    foreach my $cluster_set (@{ $cluster_sets }) {

	my @_cluster_set = @{ $cluster_set };
	if ( ! scalar( @_cluster_set ) ) {
	    die "Problem, invalid cluster set !";
	}

 	my $cluster_head = shift @_cluster_set;
	foreach my $cluster (@_cluster_set) {
	    $this->merge_nodes( $cluster_head , $cluster , $justification );
	}

	push @merged_clusters, $cluster_head;

    }

    return \@merged_clusters;

}

# cluster (stem)
sub cluster {

    my $this = shift;
    my $check_integrity = shift;

    

}

sub _cluster {

    my $this = shift;
    my $stage_name = shift;
    my $clusters = shift;
    my $mode = shift;
    my $similarity_measure = shift;
    my $similarity_threshold = shift;

    # make a copy of the array just in case
    my @clusters = @{ $clusters };

    # run hierarchical clustering on @clusters
    my $hierarchical_clusterer = new Clusterer::Hierarchical(
	mode => $mode ,
	similarity_measure => $similarity_measure ,
	similarity_threshold => $similarity_threshold
	#centroid_builder => ... 
	);
    my ($_basic_clusters, $_basic_clusters_stats) = $hierarchical_clusterer->cluster( \@clusters );
    my @basic_clusters = @{ $this->_merge_cluster_sets( $_basic_clusters , $stage_name ) };

    return \@basic_clusters;

}

# check the integrity of the gist graph
sub check_integrity {

    my $this = shift;

    # each chunk can appear in at most one node
    my %chunks2count;
    foreach my $node ( values( %{ $this->nodes() } ) ) {
	map {
	    $chunks2count{ $_ }++;
	    if ( $chunks2count{ $_ } > 1 ) {
		print STDERR "[check_integrity] chunk $_ is assigned to more than one node ...\n";
	    }
	}
	@{ $node->raw_chunks() };
    }
    
    # verify that all edges are valid
    my @edges = values %{ $this->edges() };
    my @verbalization_edges = values %{ $this->verbalization_edges() };
    my @edge_sets = ( \@edges , \@verbalization_edges );
    for (my $i=0; $i<scalar(@edge_sets); $i++) {
	
	my $edge_set = $edge_sets[ $i ];

	foreach my $edge (@{ $edge_set }) { 
	    
	    my $edge_from_node = $this->nodes()->{ $edge->from() };
	    my $edge_to_node = $this->nodes()->{ $edge->to() };
	    
	    if ( !defined($edge_from_node) || !defined($edge_to_node) ) {
		print STDERR "[check_integrity] found problematic edge ( " . $edge . " ) in set $i - from ( " . ($edge_from_node?$edge_from_node->id():'missing::' . $edge->from() ) . " ) / to ( " . ($edge_to_node?$edge_to_node->id():'missing::' . $edge->to() ) . " ) \n";
		return 0;
	    }
	    
	}
	
    }
    
    return 1;
    
} 

# return BOG node (convenience method)
sub get_bog_node {

    my $this = shift;
    
    return  $this->nodes()->{ $BOG_NODE_NAME };

}

# return EOG node (convenience method)
sub get_eog_node {

    my $this = shift;
    
    return  $this->nodes()->{ $EOG_NODE_NAME };

}

# get all neighbors for this node
sub get_connecting_edges {

    my $this = shift;
    my $node = shift;
    my $edge_type = shift;

    # get "incoming" neighbors
    my $incoming_edges = $this->edge_filter( $edge_type , sub { my $edge = shift; return ( $edge->to() eq $node->id() ); } );

    # get "outgoing" neighbors
    my $outgoing_edges = $this->edge_filter( $edge_type , sub { my $edge = shift; return ( $edge->from() eq $node->id() );} );

    return ( $incoming_edges, $outgoing_edges );

}

# get neighbors
sub get_neighbors {

    my $this = shift;
    my $node = shift;
    my $mode = shift;

    if ( ! defined( $mode ) ) {
	$mode = 1;
    }

    my ($incoming_edges,$outgoing_edges) = $this->get_connecting_edges( $node , 1 );

    my @neighbors;

    # add incoming edges
    if ( $mode >= 1 ) {
	push @neighbors, ( map { $this->nodes()->{ $_->from() }; } @{ $incoming_edges } );
    }

    # add outgoing edges
    if ( $mode <= 1 ) {
	push @neighbors, ( map { $this->nodes()->{ $_->to() }; } @{ $outgoing_edges } );
    }

    return \@neighbors;

}

# get outgoing neighbors
sub get_neighbors_outgoing {

    my $this = shift;
    my $node = shift;

    return $this->get_neighbors( $node , 0 );

}

# get incoming neighbors
sub get_neighbors_incoming {

    my $this = shift;
    my $node = shift;

    return $this->get_neighbors( $node , 2 );

}

# build context for this node
sub _build_context {

    my $this = shift;
    my $node = shift;

    # collect neighbor information
    my ( $incoming_edges , $outgoing_edges ) = $this->get_connecting_edges( $node , 1 );

    # compute incoming node distribution
    my $incoming_node_distribution = $this->_generate_neighbor_distribution( $node , $incoming_edges );

    # compute incoming edge verbalization distribution
    my $incoming_edge_verbalization_distribution = $this->_generate_edge_distribution( $node , $incoming_edges );

    # compute outgoing node distribution
    my $outgoing_node_distribution = $this->_generate_neighbor_distribution( $node , $outgoing_edges );

    # compute outgoing edge verbalization distribution
    my $outgoing_edge_verbalization_distribution = $this->_generate_edge_distribution( $node , $outgoing_edges );

    # instantiate context object
    my $context_instance = new GistGraph::Node::Context(
	count => $node->count() ,
	incoming_node_distribution => $incoming_node_distribution , outgoing_node_distribution => $outgoing_node_distribution ,
	incoming_edge_verbalization_distribution => $incoming_edge_verbalization_distribution , outgoing_edge_verbalization_distribution => $outgoing_edge_verbalization_distribution
	);

    return $context_instance;

}

# generate neighbor distribution from neighbor data
sub _generate_neighbor_distribution {

    my $this = shift;
    my $node = shift;
    my $edges = shift;

    my %neighbor_distribution;

    foreach my $edge ( @{ $edges } ) {

	my $from_node = $edge->from();
	my $to_node = $edge->to();

	my $edge_count = $edge->count();

	my $distribution_node = undef;
	if ( $from_node eq $node->id() ) {
	    $distribution_node = $to_node;
	}
	else {
	    $distribution_node = $from_node;
	}

	# update aggregate distribution data
	$neighbor_distribution{ $distribution_node } += $edge_count;

    }

    return _normalize_distribution( \%neighbor_distribution );

}

# generate edge verbalization from neighbor data
sub _generate_edge_distribution {

    my $this = shift;
    my $node = shift;
    my $edges = shift;

    my %edge_distribution;

    foreach my $edge ( @{ $edges } ) {

	# get verbalization counts for this edge
	my $edge_verbalizations_counts = $edge->verbalizations_counts();

	# update aggregate distribution data
	map {
	    $edge_distribution{ $_ } += $edge_verbalizations_counts->{$_};
	} keys( %{ $edge_verbalizations_counts } );

    }

    return _normalize_distribution( \%edge_distribution );

}

# get nodes in a sorted fashion
sub sorted_nodes {

    my $this = shift;
    my $return_ids = shift;

    my @sorted_nodes = sort { $a cmp $b } keys( %{ $this->nodes() } );
    
    if ( ! $return_ids ) {
	@sorted_nodes = map { $this->nodes()->{ $_ }; } @sorted_nodes;
    }

    return \@sorted_nodes;
}

sub plot_dir {

    my $this = shift;
    
    my $plotting_dir = join("/", $this->model_directory(), "plots");
    if ( ! -d $plotting_dir ) {
	print STDERR ">> Plottings will be created in $plotting_dir ...\n";
	mkpath $plotting_dir;
    }

    return $plotting_dir;

}

# plot gist graph
sub plot {

    my $this = shift;
    my $graph_name = shift;
    my $output_dir = shift || $this->plot_dir();

#    if ( !defined( $output_dir ) ) {
#	*OUTPUT_FILE = *STDOUT
#    }
#    else {
	my $output_file = join("/",$output_dir,join(".",$graph_name,"dot"));
	open OUTPUT_FILE, ">$output_file" or die "Unable to create output file ($output_file): $!";
#    }

    $graph_name =~ s/[[:punct:]]/_/g;

    print OUTPUT_FILE "graph $graph_name {\n";
    print OUTPUT_FILE "graph [];\n";

    my $nodes = $this->sorted_nodes();
    for (my $i=1; $i<=scalar(@{ $nodes }); $i++) {

	my $node = $nodes->[ $i - 1 ];

	my $node_id = $node->id();
	my $node_label = join(":",$node_id, $this->is_regular_node($node) ? ( $node->is_reduced() ? $node->head_string() : $node->surface_string() ) : $node_id);
	my $node_size = 2 * ( $node->genericity() || 0.1 );
	#my $node_color = $node->has_flag( $GistGraph::FLAG_SPECIFIC ) ? "green" : "red";
	my $node_color = $node->is_abstract_full() ? "green" : ( $node->is_reduced() ? "orange" : "red" );
	my $node_style = "filled";
	my $node_shape = "hexagon";
	
	print OUTPUT_FILE "\"$node_id\" [label=\"$node_label\", shape=$node_shape, style=$node_style, color=$node_color, width=$node_size, height=$node_size];\n";
	
    }
    
    my @edges = values( %{ $this->edges() } );
    foreach my $edge (@edges) {
	
	my $edge_from = $edge->from;
	my $edge_to = $edge->to;
	
	my $edge_color = "black";
	my $edge_width = $edge->get_compatibility() * 100;
	
	print OUTPUT_FILE "\"$edge_from\" -- \"$edge_to\" [penwidth=$edge_width, color=$edge_color];\n";
	
    }

    print OUTPUT_FILE "}";

    if ( defined( $output_dir ) ) {
	close OUTPUT_FILE;
    }

}

no Moose;

# decides whether two clusters are mergeable
# needs to take into account *current* merged clusters
sub _mergeable {

    # threshold underwhich we attempt to cluster NPs into other NPs ?
    # otherwise how do we stop ?

    my $cluster1 = shift;
    my $cluster2 = shift;

    # we cannot merge NPs that appear in the same summary (otherwise we lose the expressiveness power of the graph representation)
    my $cluster1_appearances = $cluster1->get_gist_occurrences();
    my $cluster2_appearances = $cluster2->get_gist_occurrences();
    foreach my $appearance1 ( keys( %{$cluster1_appearances} ) ) {
	if ( defined( $cluster2_appearances->{$appearance1} ) ) {
	    return 0;
	}
    }

=pod
    # if either one of the two chunks is rare enough (appearance ratio/appearance count)
    # we can merge
    # TODO: keep ?
    my $count_threshold = 2;
    if ( $cluster1->{count} > $count_threshold && $cluster2->{count} > $count_threshold ) {
	return 0;
    }
=cut

    return 1;

}

# edge filtering method
sub edge_filter {

    my $this = shift;
    my $edge_type = shift;
    my $filter_sub = shift;

    my @selected_edges;

    my @edges;

    if ( $edge_type == 0 ) {
	@edges = values( %{ $this->edges() } );
    }
    else {
	@edges = values( %{ $this->verbalization_edges() } );
    }


    foreach my $edge (@edges) {
	if ( $filter_sub->( $edge ) ) {
	    push @selected_edges, $edge;
	}
    }
    

    return \@selected_edges;

}

# node filtering method
sub node_filter {

    my $this = shift;
    my $filter_sub = shift;
    my $include_special_nodes = shift;

    if ( ! defined( $include_special_nodes ) ) {
	$include_special_nodes = 1;
    }

    my @selected_nodes;

    my @nodes = values( %{ $this->nodes() } );
    foreach my $node (@nodes) {
	if ( $filter_sub->( $node ) ) {
	    if ( ! $include_special_nodes ) {
		if ( ! $this->is_regular_node( $node ) ) {
		    next;
		}
	    }
	    push @selected_nodes, $node;
	}
    }

    return \@selected_nodes;
    
}

# determines whether a node (or the id it refers to) is a regular node
sub is_regular_node {

    my $this = shift;
    my $node = shift;

    my $node_id = $node;
    if ( ref($node) ) {
	$node_id = $node->id();
    }

    if ( $node_id eq $GistGraph::BOG_NODE_NAME || $node_id eq $GistGraph::EOG_NODE_NAME ) {
	return 0;
    }

    return 1;

}

# determine generic/specific split
sub _determine_generic_specific_split {

    my $this = shift;
    my $nodes = shift;

    if ( ! defined( $nodes ) ) {
	my @temp_nodes = values(%{ $this->nodes() });
	$nodes = \@temp_nodes;
    }

    my @nodes_genericity = map { $_->genericity(); } @{ $nodes };
    my $max_genericity = max(@nodes_genericity);
    my $min_genericity = min(@nodes_genericity);
    my $genericity_range = $max_genericity - $min_genericity;

    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@nodes_genericity);
    # $mean = $stat->mean();
    my $median = $stat->median();
    #$var  = $stat->variance();
    #$tm   = $stat->trimmed_mean(.25);
    #$Statistics::Descriptive::Tolerance = 1e-10;

    my @generic_nodes;
    my @specific_nodes;

    # split nodes according to median genericity value
    # the idea is that the "weight" (total number) of specific nodes should help in their identification
    # TODO: train a binary model for this decision
    # TODO: even better, use a Bayesian approach and put a prior on a node being either generic or specific
    foreach my $node (@{ $nodes }) {
	if ( $node->genericity() > $median ) {
	    push @generic_nodes, $node;
	}
	else {
	    push @specific_nodes, $node;
	}
    }

    return ( \@generic_nodes , \@specific_nodes );

}

# get list of category generic nodes (those are common to most gists in the category)
sub get_generic_nodes {

    my $this = shift;
   
    return $this->node_filter( sub { my $node = shift; return ( $node->has_flag( $FLAG_GENERIC ) ); } );

}

# get list of target specific nodes (those should be abstracted out)
# a node is target specific if:
# --> it's value appears in the target content
# --> it's value does not appear in any summary for which the target content does not contain it (this specification allows us to avoid the set any appearance threshold)
sub get_target_specific_nodes {

    my $this = shift;

    return $this->node_filter( sub { my $node = shift; return ( $node->has_flag( $FLAG_SPECIFIC ) ); } );

}

# get number of training gists
sub get_gists_count {

    my $this = shift;

    return scalar( @{ $this->raw_data()->summaries() } );

}

# get blank gist
sub get_blank_gist {

    my $this = shift;

    return new GistGraph::Gist( gist_graph => $this );

} 

# get gist object for a given training gist
sub get_gist {

    my $this = shift;
    my $index = shift;

    # fetch raw data
    my $summary = $this->raw_data()->summaries()->[ $index ];

    # instantiate Gist object
    my $gist = $this->get_blank_gist();
    $gist->initialize();

    # add regular nodes
    my $previous_node = undef;
    foreach my $summary_element ( @{ $summary } ) {
	
	my $node = $this->get_node_for_chunk( $summary_element );
	if ( ! $node ) {
	    next;
	}

	# TODO: push edge here ...

	$gist->push_node( $node );

    }

    # finalize gist
    # TOOD: pass final edge verbalization
    $gist->finalize( undef );

    return $gist;
    
}

# get gist objects for all training gists
# should we 
sub _build_gists {

    my $this = shift;

    my @training_gists;
    
    my $gist_count = $this->get_gists_count();
    for (my $i=0; $i<$gist_count; $i++) {
	push @training_gists, $this->get_gist( $i );
    }

    return \@training_gists;

}

# normalize distribution (helper function, probably belongs somewhere else ?)
sub _normalize_distribution {

    my $hash_ref = shift;

    my $sum = 0;
    my %normalized_distribution;

    # compute normalization factor
    map { $sum += $hash_ref->{$_}; } keys( %{ $hash_ref } );

    # normalize distribution
    if ( $sum ) {
	map { $normalized_distribution{ $_ } = $hash_ref->{$_} / $sum; } keys( %{ $hash_ref } );
    }

    return \%normalized_distribution;

}

1;
