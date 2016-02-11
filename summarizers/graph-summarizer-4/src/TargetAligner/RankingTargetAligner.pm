package TargetAligner::RankingTargetAligner;

use strict;
use warnings;

# CURRENT : how do we use as a standalone class ? => we still want to consume this role in TargetAdapter

use DMOZ::GlobalData;
use Web::Summarizer::TokenRanker::ReferenceBasedTokenRanker;

use Algorithm::Munkres;
use Function::Parameters qw(:strict);
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;

use Moose;
use namespace::autoclean;

extends( 'TargetAligner' );

# token ranker
has '_target_based_token_ranker' => ( is => 'ro' , isa => 'Web::Summarizer::TokenRanker' , init_arg => undef , lazy => 1 , builder => '_target_based_token_ranker_builder' );
sub _target_based_token_ranker_builder {
    my $this = shift;
    return $this->build_token_ranker( $this->target )
}

sub build_token_ranker {
    my $this = shift;
    my $object = shift;
    my $token_ranker = new Web::Summarizer::TokenRanker::ReferenceBasedTokenRanker( reference_object => $object );
    return $token_ranker;
}

sub _align {
    
    my $this = shift;
    my $target_terms_alignable = shift;
    my $reference_object = shift;
    my $reference_terms_alignable = shift;

    # we consider all pairings of utterances between the target and the reference objects
    # Note : it seems reasonable to assume that utterance pairings should be performed at a global level => the problem is how to detect unsupported tokens

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

    return \%alignment;

}

__PACKAGE__->meta->make_immutable;

1;
