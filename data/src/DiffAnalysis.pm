package DiffAnalysis;

use strict;
use warnings;

our $OPERATION_SUBSTITUTION = 's';
our $OPERATION_DELETION = 'd';
our $OPERATION_INSERTION = 'i';

my $EPSILON_DELETION = '[[__EPSILON_DELETION__]]';
my $EPSILON_INSERTION = '[[__EPSILON_INSERTION__]]';

sub diff_analysis {

    my $diff = shift;

    my @operations;

    # TODO : should we consider all tokens ?
    foreach my $diff_entry ( @{ $diff } ) {
	
	my @buffer_inserts;
	my @buffer_deletes;
	
	# Note: for now we only look for replacements
	map {
	    
	    my $edit_type = $_->[ 0 ];
	    my $edit_index = $_->[ 1 ];
	    my $edit_token = $_->[ 2 ];
	    
	    my $buffer = ( $edit_type eq '-' ) ? \@buffer_deletes : \@buffer_inserts ;

	    push @{ $buffer } , $edit_token ;
	    
	} @{ $diff_entry };
	
	my $from_string = join( " " , @buffer_deletes );
	my $to_string   = join( " " , @buffer_inserts );
	
	my $has_deletes = length( $from_string );
	my $has_inserts = length( $to_string );	

	my $operation = undef;
	if ( $has_inserts && $has_deletes ) {
	    
	    # TODO : improve LCS computation
	    if ( lc( $from_string ) eq lc( $to_string ) ) {
		next;
	    }

	    # CURRENT : improve segmentation, a lot of instances are due to punctuation characters ...
	    # CURRENT : add comparison features : first characters overlap
	    # CURRENT : add comparison features : last characters overlap

	    # substitution
	    $operation = $OPERATION_SUBSTITUTION;

	}
	elsif ( $has_inserts ) {

	    # insertion => equivalent to replacing an \epsilon with a new token
	    $operation = $OPERATION_INSERTION;
	    
	    # CURRENT : produce data for this operation as well => what would a unified adaptation model look like ?
	    $from_string = $EPSILON_INSERTION;

	}
	else {

	    # deletion => equivalent to replacing a token with an \epsilon
	    $operation = $OPERATION_DELETION;

	    # CURRENT : maybe this would be a good time to limit the number of tokens that are produced for negative instances
	    # ==> always include [[EPSILON]] ? (do we need a seperate epsilon for deletion and insertion ?)
	    $to_string = $EPSILON_DELETION;

	}

	push @operations , [ $operation , $from_string , $to_string ];

    }
    
    return \@operations;

}

1;
