package TargetAdapter::LocalMapping::SimpleTargetAdapter::RegularSlot;

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot' );

# CURRENT : candidates here could be anything that has greater salience than the original filler in the context of the target
# TODO : reduce code redundancy with WordEmbeddingSlot
method target_candidates ( $target_instance , :$length_frequence_filtering = 0 , :$minimum_modality_appearance = 0 ) {

    # ***************************************************************************************************************************************************************
    # CURRENT : dependencies should be primarity used to build (scoring) features
    # => candidates are produced by "loosely" exploring the full target space
    my %raw_candidates;

    # 1 - list out potential types for this slot

    # 2 - for each type, list out siblings

    # 3 - keep siblings that appear in / are directly compatible with the target data

    # ***************************************************************************************************************************************************************

    my @filter_terms = grep { ! $_->is_punctuation }
    map { $self->parent->original_sequence->object_sequence->[ $_ ] }
    grep {
	$self->parent->get_status( $_ ) eq $self->parent->status_supported;
    } ( $self->parent->from .. $self->parent->to );

    # Note : segment as little as possible and instead try to combine while maximizing overlap (how ?)
    my %target_candidates;

    map {
	
	# TODO : turn threshold into parameter
	# TODO : make frequency available as candidate prior
	my $_candidate = $_;
	# TODO : is there a better way ?
	my @_candidate_tokens = split /\s+/ , $_candidate;
	my $_candidate_word_length = scalar( @_candidate_tokens );
	my $target_appearance_count = ( $_candidate_word_length > 1 ) ? $target_instance->supports( $_candidate , regex_match => 1 ) : $target_instance->supports( $_candidate ) ;
	
	my $ok = 1;
	
	# length/frequency filtering => necessary unless we have a very strong type/semantic compability model
	# otherwise long/infrequent strings tend to score high (issue with compositionality ?)
	if ( $length_frequence_filtering && ( $target_appearance_count <= $_candidate_word_length ) ) {
	    $ok = 0;
	}
# TODO : to be removed - does not make any sense for abstractive slots => this is about detectic generic term replacement thus they may occur on both sides
=pod
	elsif ( $self->parent->target->supports( $_candidate ) && $self->parent->original_sequence->object->supports( $_candidate ) ) {
	    # TODO : maybe this is a bit too harsh, check for support and significance instead
	    $ok = 0;
	}
=cut
	else {
	    foreach my $filter_term (@filter_terms) {
		my $term_regex = $filter_term->create_regex( plurals => 1 );
		if ( $_candidate =~ $term_regex ) {
		    $ok = 0;
		    last;
		}
	    }
	}
	
	# CURRENT : name of the site/host should the first thing I check
	
	if ( $ok ) {
	    
	    # count of the full sequence
	    $target_candidates{ $_candidate } += $target_appearance_count;
	    
##	    # also consider count of unigrams (any reason to also do all variations ?)
##	    if ( $_candidate_word_length > 1 ) {
##		map {
##		    # we only consider terms that tend to appear on their own / in different settings
##		    # Note : a lower threshold might be useful for abstractive slot filling, but one possibility would be to obtain candidates by going in the opposite direction (how ?)
##		    #if ( $target_instance->supports( $_ ) > 2 * $target_appearance_count ) {
##		    my $candidate_surface = $_->id;
##		    if ( $target_instance->supports( $candidate_surface ) > $target_appearance_count ) {
##			$target_candidates{ $candidate_surface } += $target_appearance_count
##		    }
##		} grep { ! $_->is_punctuation } map { ref( $_ ) ? $_ : new Web::Summarizer::Token( surface => $_ ) } @_candidate_tokens;
##	    }
	    
	}
	
    }
    grep {
 	( ! $minimum_modality_appearance ) || ( $self->_modality_appearance_count( $_ ) >= $minimum_modality_appearance );
    }
    # CURRENT : is the frequency requirement always true ?
    grep {
	my $target_support = $target_instance->supports( $_ );
	# Note : the 2 occurrences threshold should ultimately be replaced by a probability distribution characterizing relevance to (non-random occurrence in) the target object
	( $target_support > 1 ) && ( $target_support > $self->parent->original_sequence->object->supports( $_ ) )
    } grep { $_ !~ m/^\p{PosixPunct}+$/ } keys( %{ $target_instance->tokens } );

    return \%target_candidates;

}

# Note : no notion of type for regular slots ?
sub type_factor {

    my $this = shift;
    my $string_2 = shift;

    return ( 1 , new Vector() , new Vector() );

}

=pod
sub factor_salience {

    my $this = shift;
    my $string2 = shift;

    my $raw_salience = $this->SUPER::factor_salience( $string2 );
    my $corrected_salience = $raw_salience;

    my $filler_support = $target_instance->supports( $this->as_string );
    if ( $filler_support ) {
	my $candidate_support = $target_instance->supports( $string2 );
	$corrected_salience **= ( 1 + ( $candidate_support / $filler_support ) );
    }

    return $corrected_salience;

}
=cut

sub type_compatible {

    my $this = shift;
    my $candidate_type = shift;

    # Note : only regular word types are compatible with abstractive slots
    # TODO : filter based on POS
    if ( defined( $candidate_type ) && $candidate_type !~ m/\#/ ) {
	return 0;
    }

    return 1;

}

__PACKAGE__->meta->make_immutable;

1;
