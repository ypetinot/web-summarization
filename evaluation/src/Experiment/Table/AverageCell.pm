package Experiment::Table::AverageCell;

use strict;
use warnings;

use Experiment::Job;

use Moose;
use namespace::autoclean;

extends( 'Experiment::Table::Cell' );
with( 'Experiment::Unit' );

# process for which a specific output variable needs to be averaged
has 'process' => ( is => 'ro' , isa => 'Experiment::Process' , required => 1 );

# float precision
has 'precision' => ( is => 'ro' , isa => 'Num' , required => 1 );

sub list_jobs {

    my $this = shift;
    my $instances = shift;

    my @jobs;

    # one job per instance
    foreach my $instance (@{ $instances }) {
	
	# CURRENT : we currently simply list out the systems (with configuration ?) and take the cross product with the set of instances
	my $job = new Experiment::Job( process => $this->process , data => $instance );
	push @jobs , $job;

    }

    return \@jobs;

}

# TODO : should the Unit class be reponsible for this kind of computations ? => e.g. create an Experiment::AverageUnit class ?
sub value_builder {

    my $this = shift;

    my $sum = 0;
    my $count = 0;

    map {
	$sum += $_;
	$count++;
    } values( %{ $this->_instances } );
    
    my $value = $count ? $sum / $count : $sum ;

     # TODO : add precision flag as a parameter
    my $value_formatted = sprintf( "%." . $this->precision . "f" , $value );

    return $value_formatted;

}

sub value_post {

    my $this = shift;
    my $value = $this->value;

    my $value_post_formatted = $this->table->post_formatting( $this , $value );

    # CURRENT : this is a table cell => add call-back to test significance ?
    # => this has to be provided at cell construction-time
    my $markers = $this->table->cell_markers( $this , $value );

    foreach my $marker_entry (@{ $markers }) {
	my $marker_significant = $marker_entry->[ 0 ];
	if ( $marker_significant ) {
	    $value_post_formatted .= ' \\dag';
	}
    }

    return $value_post_formatted;

}

__PACKAGE__->meta->make_immutable;

1;
