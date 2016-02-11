package Experiment::Process;

use strict;
use warnings;

use JSON;

use Moose;
use namespace::autoclean;

# type
has 'type' => ( is => 'ro' , isa => 'Str' , required => 1 );

# id
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 );

# params
# TOOD : enforce type
has 'params' => ( is => 'ro' , predicate => 'has_params' );

# TODO : integrate configuration generation
# [ $_->[ 0 ] , $summarizer_entry_handler , join( '=' , '--system-configuration' , to_json( $_->[ 1 ] ) ) ];

sub command {
    my $this = shift;
    my @command_elements = ( $this->command_base );
    if ( $this->has_params ) {
	push @command_elements , encode_json( $this->command_params );
    }
    my $command_string = join( " " , @command_elements ); 
    return $command_string;
}

__PACKAGE__->meta->make_immutable;

1;
