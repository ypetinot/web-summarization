package Featurizer;

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Moose::Role;

# coordinate weighter
has 'coordinate_weighter' => ( is => 'ro' , isa => 'CodeRef' , default => sub { return sub { return 1 }; } );

# TODO : can we do better ?
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
requires('_id');
sub _id_builder {

    my $this = shift;

    # 1 - stringify top level parameters
    local $Data::Dumper::Deparse = 1;
    my $local_id = md5_hex( Dumper( $this->coordinate_weighter ) );
    
    return join( "::" , $this->_id , $local_id );

}

requires('run');

1;
