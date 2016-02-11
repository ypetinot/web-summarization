package String::Alignment;

use strict;
use warnings;

use Switch;

use Moose;
use namespace::autoclean;

# from string
has 'from' => ( is => 'ro' , isa => 'ArrayRef[Str]' , required => 1 );

# to string
has 'to' => ( is => 'ro' , isa => 'ArrayRef[Str]' , required => 1 );

# cost functions
has 'cost_alignment' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_cost_alignment' );
has 'cost_deletion' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_cost_deletion' );
has 'cost_insertion' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_cost_insertion' );

sub align {

    my $this = shift;
    
    my @array;

    my $from = $this->from;
    my $to = $this->to;

    my $n_tokens_from = scalar( @{ $from } );
    my $n_tokens_to   = scalar( @{ $to   } );

    for ( my $i=0; $i<=$n_tokens_from; $i++ ) {
	for ( my $j=0; $j<=$n_tokens_to; $j++ ) {

	    my $best_cost = undef;
	    my $best_predecessor = undef;
	    my $best_operation = undef;

	    if ( $i == 0 && $j == 0 ) {
		
		$best_cost = 0;
		$best_operation = 0;

	    }
	    else {

		# Note: this is not completely clean since either $i/$j can be 0
		my $token_from = $from->[ $i - 1 ];
		my $token_to = $to->[ $j - 1 ];

		# configurations that can lead to the current cell : insert/delete/substitution
		foreach my $configuration (1,2,3) {
		    
		    my $transition_cost = undef;
		    my $predecessor = undef;
		    
		    switch( $configuration ) {
			
			# configuration 1 : ( i - 1 , j ) => delete from-token (i.e. align from-token with to-null)
			case 1 {
			    if ( $i > 0 ) {
				# cost of deletion ?
				$transition_cost = $this->has_cost_deletion ? $this->cost_deletion->( $token_from ) : 1;
				$predecessor = [ $i - 1 , $j ];
			    }
			}
			
			# configuration 2 : ( i , j - 1 ) => insert to-token (i.e. align to-token with from-null)
			case 2 {
			    if ( $j > 0 ) {
				# cost of insertion
				$transition_cost = $this->has_cost_insertion ? $this->cost_insertion->( $token_to ) : 1;
				$predecessor = [ $i , $j - 1 ];
			    }
			}
			
			# configuration 3 : ( i - 1 , j - 1 ) => replace from-token by to-token (i.e. alignment)
			case 3 {
			    if ( $i > 0 && $j > 0 ) {
				# cost of alignment
				$transition_cost = $this->has_cost_alignment ? $this->cost_alignment->( $token_from , $token_to ) : 1;
				$predecessor = [ $i - 1 , $j - 1 ];
			    }
			}
			
		    }
		
		    if ( defined( $transition_cost ) ) {

			my $cost = $array[ $predecessor->[ 0 ] ][ $predecessor->[ 1 ] ]->[ 1 ] + $transition_cost;

			if ( ! defined( $best_predecessor ) || ( $cost < $best_cost ) ) {
			    $best_cost = $cost;
			    $best_predecessor = $predecessor;
			    $best_operation = $configuration;
			}
		    }
		    
		}

	    }

	    $array[ $i ][ $j ] = [ $best_predecessor , $best_cost , $best_operation ];

	}

    }

    # determine best alignment
    my %alignment;
    # we start at [ $n_tokens_from , $n_tokens_to ]
    my $i = $n_tokens_from;
    my $j = $n_tokens_to;
    while ( ( $i != 0 ) || ( $j != 0 ) ) {
	
	my $current_entry = $array[ $i ][ $j ];
	my $current_predecessor = $current_entry->[ 0 ];
	my $current_cost = $current_entry->[ 1 ];

	if ( ( $current_predecessor->[ 0 ] == $i - 1 ) && ( $current_predecessor->[ 1 ] == $j - 1 ) ) {
	    # this is an alignment
	    $alignment{ $from->[ $i - 1 ] } = $to->[ $j - 1 ];
	}

	$i = $current_predecessor->[ 0 ];
	$j = $current_predecessor->[ 1 ];

    }
    
    return \%alignment;

}

__PACKAGE__->meta->make_immutable;

1;
