package FactorType;

use strict;
use warnings;

# CURRENT : what do I need to add here to enable the (seemless) computation of the factor value for a given configuration of the attached variables ?

use Moose::Role;

# is this a shared factor ?
has 'shared' => ( is => 'ro' , isa => 'Bool' , default => 1 );

=pod
use MooseX::Role::Parameterized;

parameter valence => (
    isa      => 'Num',
    required => 1,
    );

role {

    my $p = shift;

};
=cut

=pod
sub instantiate {

    my $this = shift;

}
=cut

1;
