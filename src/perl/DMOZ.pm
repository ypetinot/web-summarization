package DMOZ;

use strict;
use warnings;

use DMOZ::GlobalData;

#use Moose::Role;
use MooseX::Role::Parameterized;

# Not ok in roles ? => for global_data
#use MooseX::ClassAttribute;

use strict;
use warnings;

parameter remote => (
    isa => 'Bool',
    required => 0,
    default => 1
);

role {

    my $p = shift;
    my $remote = $p->remote;

    # global data
    has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , init_arg => undef , lazy => 1 , builder => '_global_data_builder' );
    method _global_data_builder => sub {
	my $this = shift;
	return new DMOZ::GlobalData( remote => $remote );
    };

};

1;
