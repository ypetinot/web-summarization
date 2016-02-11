package TargetAligner::HungarianTargetAligner;

# This aligner proceeds by pairing unsupported terms on both sides based on a global cost for each pairing => optimization necessary ?

use strict;
use warnings;

use List::Util qw/max min/;

use Moose;
use namespace::autoclean;

extends( 'TargetAligner' );
with( 'DMOZ' );

# Note : should this provided by the base class (TargetAligner) ?
with( 'TargetAligner::WordDistance' );

sub _align {
    
    my $this = shift;
    my $target_terms_alignable = shift;
    my $reference_object = shift;
    my $reference_terms_alignable = shift;

    # 2 - use hungarian algorithm to compute cost of pairing two terms together
    my @target_set = map { $_->id } @{ $target_terms_alignable };
    my @reference_set = map { $_->id } @{ $reference_terms_alignable };
    my $alignment_hungarian = $this->align_hungarian( \@target_set , $reference_object , \@reference_set , \&cost_function );

=pod
    # get target utterance sets
    my $target_utterances_sets = $this->target->utterances;
    my $reference_utterances_sets = $reference_object->utterances;

    my %alignment;

    # 1 - generate ranked list of tokens for target
    my $reference_based_token_ranker = $this->build_token_ranker( $reference_object );
    my $ranked_tokens_target = $reference_based_token_ranker->generate_ranking( $this->target );

    # 2 - generate ranked list of tokens for reference
    my $ranked_tokens_reference = $this->_target_based_token_ranker->generate_ranking( $reference_object );

    # 3 - match ranked lists based on ranking
    my $n_ranked_tokens_target = scalar( @{ $ranked_tokens_target } );
    my $n_ranked_tokens_reference = scalar( @{ $ranked_tokens_reference } );
    my $n_alignment = min( $n_ranked_tokens_target , $n_ranked_tokens_reference );
    for ( my $i=0; $i<$n_alignment; $i++ ) {
	$alignment{ $ranked_tokens_reference->[ $i ] } = [ $ranked_tokens_target->[ $i ] , 1 ];
    }
=cut

    # TODO : should this be done by align_hungarian instead ?
    my %alignment;
    map { $alignment{ $_->[ 0 ] } = [ $_->[ 1 ] , $_->[ 2 ] ] } grep { defined( $_->[ 0 ] ) } @{ $alignment_hungarian };

    return \%alignment;

}

# TODO : turn this into a role ?
sub align_hungarian {

    my $self = shift;
    my $set_1 = shift;
    my $reference_object = shift;
    my $set_2 = shift;

    my @costs;

    # 1 - compute cost matrix
    my $n_set_1 = scalar( @{ $set_1 } );
    my $n_set_2 = scalar( @{ $set_2 } );

    for ( my $i=0; $i<$n_set_1; $i++ ) {
	
	my $set_1_object = $set_1->[ $i ];

	for ( my $j=0; $j<$n_set_2; $j++ ) {
	    
	    my $set_2_object = $set_2->[ $j ];

	    my $cost_ij = $self->cost_function( $self->target , $set_1_object , $reference_object , $set_2_object );

	    $costs[ $i ][ $j ] = $cost_ij;
	    
	}

    }

    # 2 - find optimal assignment
    my @optimal_assignment;
    assign(\@costs,\@optimal_assignment);

=pod
    if ( scalar( @optimal_assignment ) < $n ) {
	die "This should never happen : input-ouput size mismatch during pairing of reference and target utterances ...";
    }
=cut

    # 3 - map to utterance pairs
    my @pairings;
    for (my $i=0; $i<=$#optimal_assignment; $i++) {

	my $optimal_j = $optimal_assignment[ $i ];

	my $set_1_object = $set_1->[ $i ];
	my $set_2_object = $set_2->[ $optimal_j ];
 
	push @pairings , [ $set_1_object , $set_2_object , $costs[ $i ][ $optimal_j ] ];

    }

    return \@pairings;

}

__PACKAGE__->meta->make_immutable;

1;
