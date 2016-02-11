package AppearanceModel;

use strict;
use warnings;

use Moose::Role;
#use namespace::autoclean;

requires "init";
requires "run";

sub entry_key {
    my $that = shift;
    my $category = shift;
    my $url = shift;
    return join( "|" , $category , $url );
}

#__PACKAGE__->meta->make_immutable;

1;
