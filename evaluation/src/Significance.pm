package Significance;

use strict;
use warnings;

use Environment;

use Moose;
use namespace::autoclean;

with( 'Logger' );

sub test_significance {

    my $this = shift;
    my $reference_distribution = shift;
    my $target_distribution = shift;
	
    # 1 - write out instances to temp file
    my $temp_fh = File::Temp->new( UNLINK => 0 );
    ##foreach my $instance_key (keys( %{ $reference_cell->_instances } )) {
    foreach my $instance_key (keys( %{ $reference_distribution } )) {

	my $reference_instance_value = $reference_distribution->{ $instance_key };
	my $instance_value = $target_distribution->{ $instance_key };
	if ( ! defined( $reference_instance_value ) || ! defined( $instance_value ) ) {
	    $this->logger->debug( "Missing instance value for : $instance_key" );
	    next;
	}

	print $temp_fh join( "\t" , $reference_instance_value , $instance_value ) . "\n";

    }
    $temp_fh->close;

    # 2 - run significance test on temp file
    # CURRENT : fix significance testing
    my $significance_script = join( '/' , Environment->evaluation_bin , 'run-significance-test-simple' );
    my @_result = map { chomp; $_ } `$significance_script $temp_fh 2>/dev/null`;
    unlink $temp_fh;

    my $significant;
    my $test_id;
    my $p_value;
    if ( scalar( @_result ) ) {
	my ( $significant_string , $_test_id , $_p_value ) = split /\s+/ , $_result[ 0 ];
	$significant = ( $significant_string eq 'significant' ) ? 1 : 0;
	$test_id = $_test_id;
	$p_value = $_p_value;
    }
    else {
	$this->logger->debug( "Significance test failed, assuming non-significant (to be fixed) ...");
	$significant = 0;
    }

    return ( $significant , $p_value , $test_id );

}

__PACKAGE__->meta->make_immutable;

1;
