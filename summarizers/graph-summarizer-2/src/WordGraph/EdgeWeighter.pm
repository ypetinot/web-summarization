package WordGraph::EdgeWeighter;

use Moose;

# full set of features
has 'features' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

# graph instances (the graph topology may change on a per-instance basis)
has 'graphs' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

# (training) paths
has 'paths' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

sub _node_edge_jaccard {

    my $this = shift;
    my $reference_path = shift;
    my $path = shift;

    my %nodes;
    my %edges;

    my $node_intersection = 0;
    my $edge_intersection = 0;

    map { $nodes{ $_ }++; } @{ $reference_path };
    foreach my $node (@{ $path }) {
	if ( defined( $nodes{ $node } ) ) {
	    $node_intersection++;
	}
	$nodes{ $node }++;
    }

    for (my $i=0; $i<scalar(@{ $reference_path })-1; $i++) {
	my $edge = join("::", $reference_path->[ $i ], $reference_path->[ $i + 1 ]);
	$edges{ $edge }++;
    }

    for (my $i=0; $i<scalar(@{ $path })-1; $i++) {
	my $edge = join("::", $path->[ $i ], $path->[ $i + 1 ]);
	if ( defined( $edges{ $edge } ) ) {
	    $edge_intersection++;
	}
	$edges{ $edge }++;
    }

    my $node_jaccard = $node_intersection / scalar( keys( %nodes ) );
    my $edge_jaccard = $edge_intersection / scalar( keys( %edges ) );

    return ( $node_jaccard , $edge_jaccard );

}

sub _norm {

    my $this = shift;
    my $vector = shift;

    my $temp_norm = 0;
    map { $temp_norm += $_^2; } values(%{ $vector });
    
    return sqrt( $temp_norm );

}

no Moose;

1;
