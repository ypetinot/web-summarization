package Experiment;

# Base class/role for all experiments

use strict;
use warnings;

use Environment;
use Experiment::Data::Instance;
use Experiment::Process;

use Config::JSON;
use File::Slurp qw/read_file/;

use Moose;
#use Moose::Role;
use namespace::autoclean;

#with('MooseX::Getopt::Dashes');
with( 'Logger' );

# TODO : should be parameterized on a system type ? something else ?

# list_jobs to be provided by sub-classes
has 'jobs' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => 'list_jobs' );

# TODO : is there a way to indicate that this is a file and that this file should exist ?
###has 'instances_list' => ( is => 'ro' , isa => 'Str' , required => 1 );

# CURRENT : is this what we want ?
# Note : units builder to be provided by sub-classes
has '_units' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_units_builder' );

sub run {

    my $that = shift;
    my $instances_list = shift;

    # 1 - create new experiment object
    my $experiment = $that->new;

    # 2 - build
    $experiment->build;

    # 3 - read instances
    my @instances = map { new Experiment::Data::Instance( id => $_ ); } read_file( $instances_list , { chomp => 1 } );

    # 3 - generate list of jobs
    # Note : all the cells in the experiment will receive all the instances, if ever needed we can apply instance-filtering at the individual cell level
    my $jobs = $experiment->list_jobs( \@instances );
    
    foreach my $job (@{ $jobs }) {
	print join( "\t" ,
		    #$job->uid ,
		    $job->data->id ,
		    $job->process->id,
		    $job->process->command
	    ) . "\n";
    }

}

sub update_units {

    my $this = shift;
    my $unit_group_id = shift;
    my $instance_id = shift;
    my $system_metrics = shift;

    # retrieve target unit
    my $units = $this->get_units( $unit_group_id );

    # submit results to unit
    if ( defined( $units ) ) {
	foreach my $unit (@{ $units }) {
	    $unit->register_job_result( $instance_id , $system_metrics );
	}
    }

}

sub get_units {

    my $this = shift;
    my $unit_group_id = shift;

# CURRENT : might even be necessary to parse the unit id
=pod
    my %system_parameters;
    my @system_parameters_key_value_pairs = split /\#/ , $system_id;
    my $system_group_id = shift @system_parameters_key_value_pairs;
    map {
	my $parameter_entry = $_;
	my ( $parameter_key , $parameter_value ) = split /\=/ , $parameter_entry;
	$system_parameters{ $parameter_key } = $parameter_value;
    } @system_parameters_key_value_pairs;

    return \%system_parameters;
=cut

    my $units = $this->_units->{ $unit_group_id };
    if ( ! defined( $units ) ) {
	print STDERR "Unable to locate units for group : ($unit_group_id) ...\n";
    }

    return $units;

}

sub post_process {

    my $that = shift;
    my $template_file = shift;
    my $output_base = shift;

    # TODO

}

1;
