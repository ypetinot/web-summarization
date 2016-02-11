package Service::Local;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : promote to a parent class ?
with( 'Logger' );

__PACKAGE__->meta->make_immutable;

1;
