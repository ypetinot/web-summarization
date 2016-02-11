package WordGraph::Decoder::ExactDecoder;

#use Moose;
#use Moose::Role;
use MooseX::Role::Parameterized;

# TODO : this has to go, but how ?
parameter reference_construction_limit => (
    isa => 'Num',
    required => 1
    );

parameter edge_model => (
    isa => 'Str',
    required => 1
    );

parameter word_graph_transformations => (
    isa => 'ArrayRef',
    default => sub { [] }
    );

role {

    my $p = shift;
    my %params;
    my $slots = $p->meta->{_meta_instance}->{slots};
    map { $params{ $_ } = $p->{ $_ } } @{ $slots };

    with( 'WordGraph::Decoder' => \%params );

    # find optimal path for the current set of weights
    method "_decode" => sub {

	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	
	# 1 - replicate graph
	my $temp_graph = $graph->replicate( $this->model , $instance );
	
	# 2 - determine shortest path
	# TODO : any way we could simply override SP_Dijksta in WordGraph ?
	###my @shortest_path = $temp_graph->SP_Dijkstra( $graph->source_node() , $graph->sink_node );
	# TODO : Bellman-Ford requires that the graph does not contain negative cycles ==> can we create a graph constructor that does not allow for such cycles ?
	my @shortest_path = $temp_graph->SP_Bellman_Ford( $graph->source_node , $graph->sink_node );
	my $shortest_path_object = new WordGraph::Path( graph => $graph , node_sequence => \@shortest_path , object => $instance->[ 0 ] , source_id => __PACKAGE__ );
	
	return ( $shortest_path_object , {} );
	
    };

};

#__PACKAGE__->meta->make_immutable;

1;
