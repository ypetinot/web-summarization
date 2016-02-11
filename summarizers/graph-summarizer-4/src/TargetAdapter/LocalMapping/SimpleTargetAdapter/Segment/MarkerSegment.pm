package TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::MarkerSegment;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment' );

has 'marker_string' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_marker_string_builder' );
has 'token_id' => ( is => 'ro' , isa => 'Num' , required => 1 );
has '_position' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_position_builder' );

sub from {
    my $this = shift;
    return $this->_position;
}

sub to {
    my $this = shift;
    return $this->_position;
}

sub _type_builder {
    my $this = shift;
    return 'f';
}

sub _is_pinned_builder {
    return 1;
} 

sub _tokens_builder {
    my $this = shift;
    my @tokens = ( new Web::Summarizer::Token( surface => $this->marker_string ) );
    return \@tokens;
}

sub _options_builder {
    my $this = shift;
    #return [ [ $this->marker_string , 1 ] ];
    return [ [ $this->tokens->[ 0 ] , 1 ] ];
}

# TODO : is this even necessary ?
sub token_ids {
    my $this = shift;
    return [ $this->token_id ];
}

__PACKAGE__->meta->make_immutable;

1;
