package Decoder;

use strict;
use warnings;

# Base class (should this be a role ) for all decoder class, that is for a processor that, given an input object return an output object
# Note : in general the space is pre-defined and implicitly defined by the decoder, however this is not necessary as the space may be conditioned on the instance considered.

use Moose::Role;
###use namespace::autoclean;

with('Logger');

requires('decode');

# training/testing mode
# by default we are in training mode
has 'test_mode' => ( is => 'rw' , isa => 'Bool' , required => 0 , default => 0 );

=pod
# space (instance) that the decoder is operating on
# Note : if we don't include the space here, the decoder would be nothing more than a generic search algorithm
has 'space' => ( is => 'ro' , does => 'Space' , required => 1 );
=cut

=pod
sub decode {

    my $this = shift;
    my $instance = shift;
    
    # TODO : might be preferable to have a sub-class overriding decode and providing support for early-update decoders
    my $instance_ground_truth_features = shift;

    # search topology using current model state
    # Question : is the topology an integral part of the search ==> yes , but the space may evolve ==> when can the space evolve ?

    # call underlying decoding procedure ?

    # return object in output space (necessarily since decoding is also used at test time)

}
=cut

# cost by the decoder in its search process
# Note : typically provided through the Model role but non-model/non-learning-based options are also possible
requires('cost');

###__PACKAGE__->meta->make_immutable;

1;
