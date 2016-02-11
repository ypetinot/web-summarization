package ReferenceTargetInstance;

use strict;
use warnings;

use Moose;
#use Moose::Role;
use MooseX::Aliases;
use MooseX::UndefTolerant;
use namespace::autoclean;

# target object
has 'target_object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# target summary
has 'target_summary' => ( is => 'rw' , isa => 'Web::Summarizer::Sequence' , alias => 'output_object' );

# references
has 'references' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# input object
has 'input_object' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => '_input_object_builder' );
sub _input_object_builder {
    my $this = shift;
    return [ $this->target_object , $this->references ];
}

sub _id_builder {
    my $this = shift;
    # TODO : should the raw_output_object be part of the id ?
    return join( "::" , $this->target_object->url , map { $_->[ 0 ]->url } @{ $this->references } );
}

with('Instance');

__PACKAGE__->meta->make_immutable;

1;
