package Experiment::Unit;

use strict;
use warnings;

use Moose::Role;
#use namespace::autoclean;

# Note : a unit is a homogeneous collection of metrics, one for each instance

# group
has 'group' => ( is => 'ro' , isa => 'Str' , required => 1 );

# id
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return join( '::' , $this->group , $this->metric );
}

# metric
has 'metric' => ( is => 'ro' , isa => 'Str' , required => 1 );

# instances
has '_instances' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# value
has 'value' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => 'value_builder' );

sub register_job_result {

    my $this = shift;
    my $instance_id = shift;
    my $metrics = shift;

    if ( defined( $this->_instances->{ $instance_id } ) ) {
	print STDERR "Instance ($instance_id) already registered ...\n";
    }
    else {
	$this->_instances->{ $instance_id } = $metrics->{ $this->metric };
    }

}

#__PACKAGE__->meta->make_immutable;

1;
