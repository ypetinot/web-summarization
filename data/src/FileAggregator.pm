package FileAggregator;

use strict;
use warnings;

use Moose::Role;
use MooseX::ClassAttribute;
with('MooseX::Getopt::Dashes');

use Digest::MD5 qw/md5_hex/;
use Getopt::Long;
use JSON;
use List::MoreUtils qw/uniq/;
use List::Util qw/shuffle/;
use Pod::Usage;

requires('aggregation_function');
requires('key_function');

# buffer
has 'buffer' => ( is => 'rw' , isa => 'ArrayRef' , default => sub { [] } );

# current entry
has 'current_entry' => ( is => 'rw' , isa => 'ArrayRef' , predicate => 'has_current_entry' );

# current key
has 'current_key' => ( is => 'rw' , isa => 'Str' );

around 'aggregation_function' => sub {
    my $orig = shift;
    my $self = shift;

    my $aggregated_buffer = $self->$orig( @_ );

    print STDOUT join( "\t" , @{ $self->current_entry } , @{ $aggregated_buffer } ) . "\n";

    # TODO : should we find a cleaner way of reinializing buffer (i.e. one that doesn't involve respecifying the empty array) ?
    $self->buffer( [] );

};

sub run {

    my $this = shift;

    while ( <STDIN> ) {
	
	chomp;
	
	my $line = $_;
	
	my ( $copy_data , $aggregation_data ) = $this->splitter_function( $line );
	
	my $key = $this->key_function( @{ $copy_data } );
	if ( $this->has_current_entry && ( $key ne $this->current_key ) ) {
	    $this->aggregation_function();
	}

	push @{ $this->buffer } , $aggregation_data;
	
	# TODO : add trigger to update key
	$this->current_entry( $copy_data );
	$this->current_key( $key );

    }
    
    # one last call if necessary
    if ( scalar( @{ $this->buffer } ) ) {
	$this->aggregation_function;
    }

}

1;
