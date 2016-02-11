package TargetAdapter::LocalMapping::SimpleTargetAdapter::AbstractiveSlot;

use strict;
use warnings;

use Function::Parameters qw/:strict/;
use List::MoreUtils qw/uniq/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::RegularSlot' );
with( 'WordNetLoader' );

# CURRENT : candidate replacements in the context of generic words ? may appear on both or neither

sub factor_salience {
    my $this = shift;
    my $candidate = shift;
    # Note : this is the opposite of WordEmbeddingSlot but this seems to be the only way to favor generic tokens (makes sense => WE is for specific attributes / A is for generic terms )
    return $this->neighborhood->neighborhood_density->{ $candidate } || 0;
}

# override cooccurrence factor
sub cooccurrence_factor {
    return 1;
}

=pod
sub similarity_factor {

    my $this = shift;
    my $sequence_surface = shift;
    my $target_candidate_surface = shift;

    my $similarity_factor = $this->semantic_relatedness( lc( $sequence_surface ) , lc( $target_candidate_surface ) );
    # TODO : in this case, and if needed, make sure all surface-relying operation use the normalized form

    return $similarity_factor;

}
=cut

sub type_siblings {

    my $this = shift;
    my $types = shift;
    
    my %siblings;
    
    foreach my $type (@{ $types }) {
	
	if ( $type =~ m/\#(.)\#(\d+)$/ ) {
	    
	    my $type_pos = $1;
	    my @type_siblings;
	    
	    # for adjectives => sim => sim
	    if ( $type_pos eq 'a' ) {
		
		# 1 - get sims for the current type
		my @type_sims = $this->wordnet_query_data->querySense( $type , 'sim' );
		
		# 2 - for each sim get sims
		@type_siblings = map {
		    $this->wordnet_query_data->querySense( $_ , 'sim' );
		} @type_sims;
		
	    }
	    # for nouns (and everything else) => hypes => hypo
	    # TODO : is this the proper way of handling adverbs ?
	    else {
		
		# 1 - get hypes for the current
		my @type_sims = $this->wordnet_query_data->querySense( $type , 'hypes' );
		
		# 2 - for each hype get hypo
		@type_siblings = map {
		    $this->wordnet_query_data->querySense( $_ , 'hypo' );
		} @type_sims;
		
	    }
	    
	    # TODO : get most specific types at source
	    map {
		$siblings{ $this->map_type_to_token( $_ ) }++;
	    } uniq @type_siblings;
	    
	}
	else {
	    
	    $this->logger->debug( 'DBpedia types are not handled currently ...' );
	    
	}
	
    }
    
    # TODO : should we abstract the action of getting to the parents separately, so that the abstract procedure is the same regardless of the ontology used ?
    # TODO : special handling for DBPedia types ?
    #my @parents = map { $this->wordnet_query_data->querySense( $_ , 'hype' ); } 
    
    my @_siblings = keys( %siblings );
    return \@_siblings;

}

sub map_type_to_token {

    my $this = shift;
    my $type_string = shift;
    
    my $token_string = $type_string;
    $token_string =~ s/\#.*$//sgi;

    return $token_string;

}

__PACKAGE__->meta->make_immutable;

1;

=pod
sub _filler_candidates_builder {

    # TODO/CURRENT : select replacements as progressively as possible
    # 1 - check the candidate appears in at least 2 modalities => remove cruft => this would make anchortext data all the more important => one thing I could do is treat boilerplate content as a separate modality (only matters if I think functionalities are not templatic) ?
    # 2 - check the candidate has compatible part-of-speech (only for regular words) or "could" be a named-entity (for named entity slots => how do I define "could")
    # 3 - check minimal type compatibility ?

    # CURRENT : find a good motivation for injecting terms from the neighborhood (stronger constraints maybe ?), otherwise drop
    # => be extremy conservative initially => non supported terms should be dropped or simplified to the maximum point
    # weekly => not supported => move up hierarchy => until we reach a node that has descendants
    # TODO : move up type hierarchies in parallel => find candidates in the target that agree with at least one of the hierarchy types
    # TODO : use neighborhood prior to score those candidates, not as a source of candidates

###    # identify all terms that have a non-zero prior in the neighborhood
###    my $neighborhood_candidates = $this->parent->neighborhood->get_summary_terms(
###	$this->parent->original_sequence->object,
###	check_not_supported => 1,
###	prior_threshold => 0.1 );

    # target candidates
    my $candidates = $this->_target_candidates( length_frequence_filtering => 1 , minimum_modality_appearance => 2 );

    # boost candidates based on target appearance
    my %filler_candidates;
    map {
	# TODO : anyform of boosting needed here ? => density estimates
	$filler_candidates{ $_ } = $candidates->{ $_ };
    }
    grep {

	my $keep = 1;

	# make sure POS is compatible (only for regular words - does not apply to phrases ?)
	if ( $this->length == 1 ) {
	    my $slot_pos = $this->parent->analyzer->_wordnet_pos( $this->key );
	    my $candidate_pos = $this->parent->analyzer->_wordnet_pos( $_ );
	    my $pos_overlap = 0;
	    map { $pos_overlap += defined( $candidate_pos->{ $_ } ) } keys( %{ $slot_pos } );
	    if ( ! $pos_overlap ) {
		$keep = 0;
	    }
	}

	# filter by type
	my $type_signature = $this->parent->type_signature( $_ );
	if ( $this->parent->target->is_named_entity( $_ ) ) {
	    $keep = 0;
	}
	elsif ( defined( $type_signature->coordinates->{ 'type-entity' } ) ) {
	    $keep = 0;
	}
	else {
	    # compare slot type(s) with candidate type
	    if ( ! Vector::cosine( $this->type_signature , $type_signature ) ) {
		$keep = 0;
	    }
	}

	$keep;

    }
    grep {
	# TODO : this should probably be promoted to the Slot class as a generic filter ?
	# do not consider terms that appear in the original summary
	! $this->parent->original_sequence->object->summary_modality->supports( $_ );
    }
    keys( %{ $candidates } );

    return \%filler_candidates;

}
=cut
