package WordGraph::Node::EmittingNode;

use strict;
use warnings;

# TODO : is there any reason why this should be implemented as a Role ?

use Moose;
use namespace::autoclean;

# (conditional) distribution associated with this node
has 'distribution' => ( is => 'ro' , isa => 'Distribution' , required => 1 );

extends 'WordGraph::Node';

__PACKAGE__->meta->make_immutable;

1;
