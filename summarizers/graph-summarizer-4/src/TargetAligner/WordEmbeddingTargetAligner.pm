package TargetAligner::WordEmbeddingTargetAligner;

use strict;
use warnings;

use DMOZ::GlobalData;
use Web::Summarizer::TokenRanker::ReferenceBasedTokenRanker;

use Algorithm::Munkres;
use Function::Parameters qw(:strict);
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;

use Moose;
use namespace::autoclean;

extends( 'TargetAligner' );
with( 'TargetAligner::WordDistance' );

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

    my %alignment;

    # For each reference term , find closest target term
    my $n_target_terms_alignable = scalar( @{ $target_terms_alignable } );
    my $n_reference_terms_alignable = scalar( @{ $reference_terms_alignable } );
    for ( my $i = 0 ; $i < $n_reference_terms_alignable ; $i++ ) {

	my $reference_term_alignable = $reference_terms_alignable->[ $i ]->surface;
	
	my $min_distance = 1;
	my $min_distance_candidate = undef;
	
	for ( my $j = 0 ; $j < $n_target_terms_alignable ; $j++ ) {

	    my $target_term_alignable = $target_terms_alignable->[ $j ]->surface;
	    
	    # TODO : use full-fledged word distance
	    my $distance = $this->semantic_distance( $reference_term_alignable , $target_term_alignable );
	    
	    if ( $distance < $min_distance ) {
		$min_distance_candidate = $target_term_alignable;
		$min_distance = $distance;
	    }

	}

	if ( defined( $min_distance_candidate ) ) {
	    $alignment{ $reference_term_alignable } = [ $min_distance_candidate , $min_distance ];
	}

    }

    return \%alignment;

}

__PACKAGE__->meta->make_immutable;

1;
