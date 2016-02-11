package GistGraph::Edge::Verbalization;

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use List::Util qw/min max/;

extends 'GistGraph::Edge';
with Storage('format' => 'JSON', 'io' => 'File');

# Fields

# edge verbalizations - direction 1
has 'verbalizations' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

# edge verbalizations counts (i.e. unormalized distribution)
has 'verbalizations_counts' => (is => 'rw', isa => 'HashRef', default => sub { {} });

our $DEBUG = 0;

# add verbalization to this edge
sub add_verbalization {

    my $this = shift;
    my $verbalization = shift;
    my $count = shift || 1;

    my $verbalization_key = $this->_get_verbalization_key( $verbalization );

    # update verbalizations ( if needed )
    if ( ! defined( $this->verbalizations_counts()->{ $verbalization_key } ) ) {
	# print STDERR "[Verbalization edge: $this] registering verbalization: $verbalization_key\n";
	my @verbalization_copy = @{ $verbalization };
	push @{ $this->verbalizations() }, \@verbalization_copy;
	$this->verbalizations_counts()->{ $verbalization_key } = 0;
    }

    # print STDERR "Verbalization key: $verbalization_key\n";

    # update verbalizations counts
    $this->verbalizations_counts()->{ $verbalization_key } += $count;

    # basic check
    if ( $DEBUG ) {
	
	if ( ! defined( $this->verbalizations_counts()->{ $verbalization_key } ) ) {
	    die __PACKAGE__ . " - invalid verbalization count for $verbalization / $verbalization_key";
	}

	# make sure verbalization counts correspond to actual verbalizations
	foreach my $_verbalization_key ( keys %{ $this->verbalizations_counts() } ) {

	    my $found = 0;
	    my $local_count = $this->verbalizations_counts()->{ $_verbalization_key };

	    foreach my $_verbalization ( @{ $this->verbalizations() } ) {
		
		my $_local_verbalization_key = $this->_get_verbalization_key( $_verbalization );
		if ( $_local_verbalization_key eq $_verbalization_key ) {
		    $found = 1;
		}

	    }
	    
	    if ( ! $found ) {
		use Data::Dumper;
		print STDERR Dumper( $this->verbalizations() ) . "\n";
		print STDERR Dumper( $this->verbalizations_counts() ) . "\n";
		die __PACKAGE__ . " - invalid entry in verbalizations counts: $_verbalization_key / $local_count";
	    }

	}
	
	# make sure we don't have two verbalizations that are identical
	my %seen;
	foreach my $_verbalization ( @{ $this->verbalizations() } ) {
	    
	    my $verbalization_key = $this->_get_verbalization_key( $_verbalization );
	    
	    if ( defined( $seen{ $verbalization_key } ) ) {
		use Data::Dumper;
		print STDERR Dumper( $this->verbalizations() ) . "\n";
		print STDERR Dumper( $this->verbalizations_counts() ) . "\n";
		die __PACKAGE__ . " - found replicated verbalizations in verbalization edge: $verbalization_key";
	    }

	    $seen{ $verbalization_key } = 1;

	}

    }

}

# verbalization key
sub _get_verbalization_key {

    my $this = shift;
    my $verbalization = shift;

    # TODO: should we add some normalization here ?

    return join( "-" , @{ $verbalization } );

}

# merge an edge into this edge
sub merge {

    my $this = shift;
    my $edge = shift;

    print STDERR "Merging verbalization edge $edge into verbalization edge $this ...\n";

    foreach my $verbalization ( @{ $edge->verbalizations() } ) {

	my $verbalization_key = $edge->_get_verbalization_key( $verbalization );
	my $verbalization_count = $edge->verbalizations_counts()->{ $verbalization_key };
	
	if ( $DEBUG ) {

	    if ( !defined( $verbalization_count ) ) {
		my $edge_total_count = $edge->count();
		my $edge_verbalizations = join(" :: ", map { join("-", @{ $_ } ); } @{ $edge->verbalizations() });
		die __PACKAGE__ . " - verbalization count cannot be undefined ($verbalization_key) - (total count:$edge_total_count) - (verbalizations:$edge_verbalizations)";
	    }

	}

	my $current_verbalization_count = $this->verbalizations_counts()->{ $verbalization_key } || 0;

	$this->add_verbalization( $verbalization , $verbalization_count );

	# make sure the verbalization has effectively been added
	if ( $DEBUG ) {

	    my $new_verbalization_count = $this->verbalizations_counts()->{ $verbalization_key };
	    if ( !defined( $new_verbalization_count ) || ( $new_verbalization_count != $verbalization_count + $current_verbalization_count ) ) {
		die __PACKAGE__ . " - mismatch between verbalization counts for $verbalization ($verbalization_key): $new_verbalization_count / $verbalization_count / $current_verbalization_count";
	    }

	}

    }
    
}

# total appearance count for this edge
sub count {

    my $this = shift;
    
    my $count = 0;
    map { $count += $_ } values( %{ $this->verbalizations_counts() } );

    return $count;

}

# identify most likely verbalization for this edge
sub mle_verbalization {

    my $this = shift;

    my $verbalization_index = 0;
    my $current_max = 0;
    for (my $i=0; $i<scalar( @{ $this->verbalizations() } ); $i++) {

	my $verbalization_key = $this->_get_verbalization_key( $this->verbalizations()->[ $i ] );
	my $verbalization_count = $this->verbalizations_counts()->{ $verbalization_key };

	if ( ! defined( $verbalization_count ) ) {
	    print STDERR "Problem: unknow verbalization key: $verbalization_key\n";
	    $verbalization_count = 0;
	}
	
	if ( $verbalization_count > $current_max ) {
	    $current_max = $verbalization_count;
	    $verbalization_index = $i;
	}

    }

    return $verbalization_index;

}

# verbalize this edge (either deterministically if a verbalization id is given, or as a sample from the verbalization distribution)
sub verbalize {

    my $this = shift;
    my $verbalization_index = shift;

    my $target_index = $verbalization_index;

    if ( ! defined( $target_index ) ) {
	# for now
	$target_index = 0;
    }

    if ( $DEBUG ) {
	print STDERR "[Verbalization::verbalize] verbalizing edge - from ( " . $this->from() . " ) / ( " . $this->to() . " ) \n";
    }

    return join( " ", map{ $this->gist_graph()->raw_data()->get_chunk( $_ )->get_surface_string(); } @{ $this->verbalizations()->[ $target_index ] } );

}

no Moose;

1;
