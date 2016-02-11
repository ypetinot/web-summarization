package Modality::Operator;

use strict;
use warnings;

use Moose::Role;
#use namespace::autoclean;

requires( '_id' );
requires( 'process' );
requires( 'run' );

has 'parent' => ( is => 'ro' , isa => 'Modality::Operator' , predicate => 'has_parent_operator' );

sub id {
    my $this = shift;
    
    my @id_components = ( $this->id );
    if ( $this->has_parent_operator ) {
	unshift @id_components , $this->parent->id;
    }

    return join( '.' , @id_components );
}

sub run {

    my $this = shift;
    my $url_data = shift;

    # 1 - get parent data
    my $parent = $this->has_parent_operator ? $this->parent : undef;

    # 2 - apply operator on parent data
    my $result = $this->process->( $url_data , $parent );

    # CURRENT : is there a way to determine if we are at the end of the pipeline ?

    return $this;

}

sub value {

    my $this = shift;
    my $url_data = shift;

    $this->run( $url_data );

    ...

}


#__PACKAGE__->meta->make_immutable;

1;
