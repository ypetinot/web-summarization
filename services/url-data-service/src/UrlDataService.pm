package UrlDataService;

# CURRENT/TODO : migrate towards a proxy for DMOZ::GlobalData since we are now accessing url data through a shared data stored that is updated in a truly distributed way

use strict;
use warnings;

#use AppearanceModel::Individual;
use DMOZ::CategoryRepository;
use DMOZ::GlobalData;
use Environment;

use Moose;
#use MooseX::NonMoose::InsideOut;
use MooseX::ClassAttribute;
use MooseX::NonMoose;

extends 'JSON::RPC::Procedure';

# global data
class_has 'global_data' => ( is => 'ro' ,
		       isa => 'DMOZ::GlobalData' ,
		       init_arg => undef ,
		       lazy => 1 ,
		       builder => '_global_data_builder'
    );
sub _global_data_builder {
    my $this = shift;
    return new DMOZ::GlobalData( remote => 0 );
}

sub global_count {
        my $this = shift;
	my $args = $_[ 0 ];
	return $this->global_data->global_count( @{ $args } );
}

# no need to fiddle with inline_constructor here
__PACKAGE__->meta->make_immutable;

1;
