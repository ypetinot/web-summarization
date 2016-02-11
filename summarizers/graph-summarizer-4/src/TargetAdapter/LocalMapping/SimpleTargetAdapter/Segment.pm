package TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment;

# Abstracts the notion of a segment:
# 1 - initial set of token
# 2 - set of options
# TODO : can we do better ?

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

has 'id' => ( is => 'ro' , isa => 'Num' , required => 1 );
has 'type' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_type_builder' );

# parent sequence
has 'parent' => ( is => 'ro' , isa => 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence' , required => 1 );

sub is_function {
    my $this = shift;    
    return ( $this->type eq 'f' );
}

sub is_abstractive {
    my $this = shift;
    #return ( $is_slot && ref( $this->_slots->{ $slot_id } ) =~ m/Abstractive/ ) ? 1 : 0;
    return ( $this->type =~ m/Abstractive/ ) ? 1 : 0;
}

method get_segment_successors_ids( :$all_successors = 1 ) {
    
    # we map ...
    my %segments_successors_ids;
    # Note : token_id refers to a token in the original sequence
    foreach my $token_id ( @{ $self->token_ids } ) {
	
	# get successors for this token
	my @token_successors = $all_successors ? $self->parent->component_dependencies_disconnected->all_successors( $token_id ) :
	    $self->parent->component_dependencies_disconnected->successors( $token_id );
	
	# map token id to segment id
	map {
	    my $segment_successor_id = $self->parent->_token_2_segment->{ $_ };
	    if ( $segment_successor_id != $self->id ) {
		$segments_successors_ids{ $segment_successor_id }++;
	    }
	} @token_successors;
	
    }

    my @segment_successors_ids = keys( %segments_successors_ids );
    return \@segment_successors_ids;

}

sub get_segment_successors {

    my $this = shift;
    my $all_successors = shift;
    
    my $segment_successors_ids = $this->get_segment_successors_ids( all_successors => $all_successors );
    my @segment_successors = map { $this->parent->get_segment( $_ ); } @{ $segment_successors_ids };

    return \@segment_successors;

}

# TODO : does not quite make sense to have this field here, but currently needed by MarkerSegment
# options
has 'options' => ( is => 'ro' , isa => 'ArrayRef' , lazy => 1 , builder => '_options_builder' );

# is pinned ?
has 'is_pinned' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_is_pinned_builder' );
sub _is_pinned_builder {
    return 0;
} 

# tokens comprising this segment
has 'tokens' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_tokens_builder' );

has 'original_as_token' => ( is => 'ro' , isa => 'Web::Summarizer::Token' , init_arg => undef , lazy => 1 , builder => '_original_as_token_builder' );
sub _original_as_token_builder {
    my $this = shift;
    return new Web::Summarizer::Token( surface => join( ' ' , map { $_->surface } @{ $this->tokens } ) );
}

__PACKAGE__->meta->make_immutable;

1;
