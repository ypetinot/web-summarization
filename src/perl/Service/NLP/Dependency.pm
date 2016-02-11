package Service::NLP::Dependency;

# TODO : is this the right package for this ?

use strict;
use warnings;

use Carp::Assert;
use JSON;

use Moose;
use namespace::autoclean;

with( 'Logger' );

has 'dependency_string' => ( is => 'ro' , isa => 'Str' , required => 1 );
has 'dependency_data' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_dependency_data_builder' );
sub _dependency_data_builder {
    my $this = shift;
    return $this->parse_dependency( $this->dependency_string );
}

sub from {
    my $this = shift;
    return $this->dependency_data->{ 'from' };
}

sub from_id {
    my $this = shift;
    return $this->dependency_data->{ 'from_id' };
}

sub to {
    my $this = shift;
    return $this->dependency_data->{ 'to' };
}

sub to_id {
    my $this = shift;
    return $this->dependency_data->{ 'to_id' };
}

sub type {
    my $this = shift;
    return $this->dependency_data->{ 'type' };
}

sub parse_dependency {
    my $this = shift;
    my $dependency_string = shift;

    if ( $dependency_string !~ m/^([^\(]+)\(([^ ]+)\, (.+)\)$/ ) {
	$this->logger->debug( "Unexpected dependency format: $dependency_string" );
	die;
    }
    
    my $dependency_type = $1;
    my $dependency_key_from = $2;
    my $dependency_key_to = $3;
    
    my ( $dependency_from , $dependency_from_id ) = $this->_parse_dependency_key( $dependency_key_from );
    my ( $dependency_to , $dependency_to_id ) = $this->_parse_dependency_key( $dependency_key_to );

    my %dependency_data;
    $dependency_data{ 'from' } = $dependency_from;
    $dependency_data{ 'from_id' } = $dependency_from_id;
    $dependency_data{ 'to' } = $dependency_to;
    $dependency_data{ 'to_id' } = $dependency_to_id;
    $dependency_data{ 'type' } = $dependency_type;     

    return \%dependency_data;

}

# TODO : merge regex below with the one above ?
sub _parse_dependency_key {
    my $this = shift;
    my $dependency_node_key = shift;
    # Note : the ' marks replicated tokens for the sake of dependency analysis ? Might become a source of problem, but simply ignoring for now.
    if ( $dependency_node_key !~ m/^(.+)\-(\d+)\'*$/ ) {
	affirm { 0 } "Dependency key must follow expected format: $dependency_node_key" if DEBUG;
    }
    my $dependency_node_string = $1;
    my $dependency_node_id = $2;
    
    # Note : assertion does not work with multi-word tokens, taking this out for now.
    #affirm { ( ! $dependency_node_id ) || ( $this->object_sequence->[ $sequence_node_id ]->surface eq $dependency_node_string ) } 'Nodes must match' if DEBUG;
    
    return ( $dependency_node_string , $dependency_node_id );
}

sub TO_JSON {
    my $this = shift;
    #return encode_json( { 'dependency_string' => $this->dependency_string } );
    return $this->dependency_string;
}

sub FROM_JSON {
    my $this = shift;
    my $json_string = shift;
    my $json_string_decoded = decode_json( $json_string );
    return __PACKAGE__->new( 'dependency_string' => $json_string_decoded->{ 'dependency_string' } ); 
}

__PACKAGE__->meta->make_immutable;

1;
