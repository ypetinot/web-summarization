package GistGraph::Edge;

# --> edges are defined as bags of chunks (also) (as identified by their ids)

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use List::Util qw/min max/;

with Storage('format' => 'JSON', 'io' => 'File');

our $DEBUG = 1;

# gist graph back pointer
has 'gist_graph' => (is => 'rw', isa => 'GistGraph', required => 0, traits => [ 'DoNotSerialize' ]);

# from node
has 'from' => (is => 'rw', isa => 'Str', required => 1);

# to node
has 'to' => (is => 'rw', isa => 'Str', required => 1);

# occurrences
has 'occurrences' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# average distance (proximity)
has 'average_distance' => (is => 'rw', isa => 'Num', default => 0);

# add occurrence of this edge
sub add_occurrence {

    my $this = shift;
    my $gist_id = shift;
    my $distance = shift;
    my $count = shift || 1;

    my $current_count = $this->occurrences()->{ $gist_id } || 0;

    # update occurrences
    $this->occurrences()->{ $gist_id } = $current_count + $count;

    # update average_distance
    $this->average_distance( ( $this->average_distance() * $current_count + $distance * $count ) / ( $current_count + $count ) );

}

# merge an edge into this edge
sub merge {

    my $this = shift;
    my $edge = shift;

    # merge occurrences
    foreach my $gist_id ( keys( %{ $edge->occurrences() } ) ) {
	# TODO: can we make this slightly more accurate ? the averaging is wrong ...
	$this->add_occurrence( $gist_id , $edge->average_distance(), $edge->count() );
    }

}

# total appearance count for this edge
sub count {

    my $this = shift;
    
    my $count = 0;
    map { $count += $_ } values( %{ $this->occurrences() } );

    if ( $DEBUG && $count == 0 ) {
	die "Problem: found edge with 0 count: (" . $this->from() . "," . $this->to() . ") ...";
    }

    return $count;

}

# get proximity for the nodes connected by this edge
sub get_proximity {

    my $this = shift;

    # Proximity is computed as the average distance (in NP positions) between the nodes defining this edge
    return $this->average_distance();

}

# get compatibility for the nodes connected by this edge
sub get_compatibility {

    my $this = shift;

    # Compatibility is computed as the number of times the nodes defining this edge appear together
    # TODO: note that right now this is a bit of an approximation as an edge may occur more than once in a single gist (though this shouldn't be the case)
    return min( $this->count() / $this->gist_graph()->get_gists_count() , 1 );

}

no Moose;

1;
