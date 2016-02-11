package NPModel;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# id
# TODO : get support for this field through identifiable ?
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 , reader => 'get_id' );

__PACKAGE__->meta->make_immutable;

1;
