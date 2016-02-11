package Experiment::Table::Cell;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# parent table
has table => ( is => 'ro' , isa => 'Experiment::Table' , required => 1 );

# row index
has row => ( is => 'ro' , isa => 'Num' , required => 1 );

# column index
has column => ( is => 'ro' , isa => 'Num' , required => 1 );

# default implementation
sub list_jobs {

    my $this = shift;
    
    # by default we return an empty list
    return [];

}

# default implementation - can be overridden by sub-classes
sub value_post {
    my $this = shift;
    return $this->value;
}

__PACKAGE__->meta->make_immutable;

1;
