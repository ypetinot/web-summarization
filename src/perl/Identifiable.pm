package Identifiable;

use strict;
use warnings;

#use Moose::Role;
use MooseX::Role::Parameterized;

parameter id => (
    isa      => 'Str',
    required => 0
);

role {
    
    my $p = shift;
    my $id = $p->id;    

    # id
    # TODO : can we do better ?
    if ( defined( $id ) ) {
	has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 , default => sub { $id } );

    }
    else {
	has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
    }

};

1;
