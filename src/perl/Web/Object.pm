package Web::Object;

use strict;
use warnings;

use Moose::Role;
use Moose::Util::TypeConstraints;

subtype 'URI',
    as 'URI';

#provide a coercion
coerce 'URI',
    from 'Str',
    via { URI->new( $_ ) };

# url
has 'url' => ( is => 'ro' , isa => 'URI' , required => 1 , coerce => 1 );

# TODO : does this belong here ?
sub key_generator {
    my $this = shift;
    # TODO : any reason what we should instead stringify the canonical form of the URI ?
    return $this->url->as_string;
}

1;
