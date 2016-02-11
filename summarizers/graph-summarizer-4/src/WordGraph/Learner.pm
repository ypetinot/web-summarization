package WordGraph::Learner;

# Base class for all WordGraph-based learners - the purpose of this class is to provide a base abstraction for all learners making use of the WordGraph topology.
# A specificity of this family of learners is that is has access to a set of reference (summary, object) pairs for each (?) training instance.

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends('Learner');

# run (overridden)
# TODO : remove ? might have become useless ?
sub run {

    my $this = shift;
    my $model = shift;
    my $decoder = shift;
    my $training_instances = shift;

    # we delegate to the parent class - the training instances are now tuples
    return $this->SUPER::run( $model , $decoder , \@transformed_training_instances );

}

__PACKAGE__->meta->make_immutable;

1;
