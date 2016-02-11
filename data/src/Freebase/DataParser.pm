package Freebase::DataParser;

use strict;
use warnings;

use Text::Trim;

use Moose;
use namespace::autoclean;

with( 'Logger' );

# TODO : rewrite using EntryGrouper

sub _get_key {
    my $this = shift;
    my $concept_marker = shift;
    my $key = $concept_marker;
    $key =~ s/^<http:.+ns\/(.+)>$/$1/sgi;
    return $key
}

sub _get_value {
    my $this = shift;
    my $raw_value = shift;
    my $value = $raw_value;
    $value =~ s/^"([^"]+)".*$/$1/sgi;
    return trim( $value );
}

sub run {

    my $this = shift;

    my $current_entity_key = undef;
    my @entries;
    while( <STDIN> ) {  
	
	chomp;
	
	my $line = $_;
	if ( $line =~ m/^\#/ ) {
	    next;
	}

	my @fields = split /\t/ , $line;
	
	my $concept_freebase = $fields [ 0 ];
	my $concept_entity_key = $this->_get_key( $concept_freebase );
	if ( defined( $current_entity_key ) && ( $current_entity_key ne $concept_entity_key ) ) {
	    $this->processor_function->( $current_entity_key , \@entries );
	    @entries = ();
	}
	$current_entity_key = $concept_entity_key;
	
	my $relation_marker = $fields[ 1 ];
	my $attribute_key = $this->_get_key( $relation_marker );
	if ( ! $this->filter_function->( $attribute_key ) ) {
	    next;
	}
	
	push @entries , \@fields;
	
    }
    
    $this->processor_function->( $current_entity_key , \@entries );
    
}

__PACKAGE__->meta->make_immutable;

1;
