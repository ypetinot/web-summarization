package Feature::ReferenceTargetFeature;

# Base role for all features used by ReferenceTargetModel's.

use strict;
use warnings;

###use Moose::Role;
use MooseX::Role::Parameterized;

parameter type => (
    isa      => 'Str',
    required => 1,
    );

role {

    my $p = shift;

=pod
# object1
###has 'object1' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );
has 'object1' => ( is => 'ro' , isa => $p->type , required => 1 );

# object2
###has 'object2' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );
has 'object2' => ( is => 'ro' , isa => $p->type , required => 1 );
=cut

};

1;
