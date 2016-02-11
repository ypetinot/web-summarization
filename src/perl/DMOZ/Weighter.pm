package DMOZ::Weighter;

use strict;
use warnings;

use MooseX::Role::Parameterized;

parameter field => (
    isa => 'Str',
    required => 1
    );

role {

    # weighter
    has 'weighter' => ( is => 'ro' , isa => 'CodeRef' , builder => '_weighter_builder' );
    method _weighter_builder => sub {
	
	my $this = shift;
	
	my $weighter = sub {
	    my $object = shift;
	    my $order = shift;
	    my $feature = shift;
	    # CURRENT : access global data via a service
	    my $corpus_size = $this->global_data->global_count( 'summary' , $order );
	    my $global_count = $this->global_data->global_count( 'summary' , $order , join( " " , ref( $feature ) ? @{ $feature } : $feature ) );
	    my $weight = log ( $corpus_size / ( 1 + $global_count ) );
	    
	    if ( $weight < 0 ) {
		$this->error( "Invalid Weight for feature ($feature) is negative: $weight");
	    }
	    
	    return $weight;
	};
	
	return $weighter;
	
    };

};

1;
