package Experiment::Job;

# Unique combination of a process specification and a data object.
# Both the process and data must be identifiable.

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# process
has 'process' => ( is => 'ro' , isa => 'Experiment::Process' , required => 1 );

# data
has 'data' => ( is => 'ro' , isa => 'Ref' , required => 1 );

# unique id for this job
sub uid {
    my $this = shift;
    return join( "/" , $this->process->id , $this->data->id );
}

__PACKAGE__->meta->make_immutable;

1;
