package Instance;

use strict;
use warnings;

use Moose::Role;
with('MooseX::Clone');

# Note : currently necessary if parameter aliasing is used by any consuming class
use MooseX::Aliases;

# TODO : ideally we would want Identifiable to make the id field required , parameterizable role in case a consuming class wants to provide a custom id method ?
with('Identifiable');

# TODO : mapping from raw input/ouput object into/from learning instance variables ?

# input object
#has 'input_object' => ( is => 'ro' , required => 1 );
requires('input_object');

# output object (if known)
#has 'output_object' => ( is => 'rw' , required => 0 );
requires('output_object');

# instances are featurizable
# TODO : create a Featurizeable role ?
# Note : no longer relevant ?
###requires('featurize');

# CURRENT : what if we also include instance-specific constructs that affect the x -> y mapping but that is given and not learned ...
# CURRENT : e.g. instance-specific decoding process ?

1;
