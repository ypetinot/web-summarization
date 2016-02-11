package EntryGrouper;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : does this belong here ?
binmode( STDIN , ':utf8' );
binmode( STDOUT , ':utf8' );

has 'key_function' => ( is => 'ro' , isa => 'CodeRef' , default => sub { \&default_key_generator } );

# filter function
has 'filter_function' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_filter_function');

# processor function
has 'processor_function' => ( is => 'ro' , isa => 'CodeRef' , required => 1 );

sub default_key_generator {
    my $fields = shift;
    return $fields->[ 0 ];
}

sub run {

    my $this = shift;

    my $current_key = undef;
    my @entries;
    while( <STDIN> ) {  
	
	chomp;
	
	my $line = $_;
	if ( $line =~ m/^\#/ ) {
	    next;
	}

	my @fields = split /\t/ , $line;
	
	my $key = $this->key_function->( \@fields );
	if ( defined( $current_key ) && ( $current_key ne $key ) ) {
	    $this->processor_function->( $current_key , \@entries );
	    @entries = ();
	}
	$current_key = $key;
	
	if ( $this->has_filter_function && ! $this->filter_function->( \@fields ) ) {
	    next;
	}
	
	push @entries , \@fields;
	
    }
    
    $this->processor_function->( $current_key , \@entries );
    
}

__PACKAGE__->meta->make_immutable;

1;
