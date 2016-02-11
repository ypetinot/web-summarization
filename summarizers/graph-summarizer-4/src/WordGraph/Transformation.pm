package WordGraph::Transformation;

use strict;
use warnings;

# Base role/class for all word-graph transformations.

use Moose::Role;

requires('transform');

# TODO : create super-role 'Thing' ?
with('Logger');

1;
