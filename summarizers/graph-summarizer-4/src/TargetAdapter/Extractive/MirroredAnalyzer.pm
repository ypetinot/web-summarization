package TargetAdapter::Extractive::MirroredAnalyzer;

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::Extractive::Analyzer' );

method mutual ( $instance_target , $instance_reference , :$target_threshold = 0 , :$reference_threshold = 0 ) {

    # 1 - identify function terms => supported by both instance_target and instance_reference
    my $instance_target_tokens = $instance_target->tokens;
    my %function_terms;
    foreach my $token_id (keys( %{ $instance_target_tokens } )) {
	my $instance_target_token = $instance_target_tokens->{ $token_id }->[ 0 ];
	if ( $instance_target_token->is_punctuation ) {
	    next;
	}
	elsif ( $instance_reference->supports( $instance_target_token ) ) {
	    $function_terms{ $instance_target_token->id } = $instance_target_token;
	}
    }

    # 2 - segment each instance's utterances on function term
    my ( $instance_1_unsupported_sequences , $instance_2_unsupported_sequences ) = map {
	$self->analyze_sequence( $_->[ 0 ] ,
				 $_->[ 1 ] ,
				 \%function_terms,
				 threshold => $_->[ 3 ] ,
				 use_summary => $_->[ 2 ] );
    } ( [ $instance_target , $instance_reference , 0 , $target_threshold || 2 ] , [ $instance_reference , $instance_target , 0 , $reference_threshold || 0 ] );

    return ( $instance_1_unsupported_sequences , $instance_2_unsupported_sequences , \%function_terms );

}

method analyze_sequence ( $instance_target , $instance_reference , $function_terms , :$threshold = 0 , :$use_summary = 0 ) {

    $self->logger->debug( __PACKAGE__ . join( " <-> " , map { $_->url } ( $instance_target , $instance_reference ) ) );

    # create segmentation regex
    my $segmentation_regex = join( '|' , map { $_->as_regex } values( %{ $function_terms } ) );
    my $segmentation_regex_object = qr/$segmentation_regex/isa;

    my %unsupported_sequences;
    my %raw_unsupported_sequences_surfaces;

    # for all utterances identify "sequences" of tokens that are unsupported by the other instance    
    my $target_utterances = $instance_target->utterances;

    # TODO : this should be promoted to UrlData::utterances with proper parameters
    if ( $use_summary ) {
	my %_target_utterances = %{ $target_utterances };
	$_target_utterances{ 'summary' } = $instance_target->summary_modality->utterances;
	$target_utterances = \%_target_utterances;
    }

    foreach my $target_utterance_source (keys( %{ $target_utterances })) {

	foreach my $target_utterance (@{ $target_utterances->{ $target_utterance_source } }) {
	    
	    my $target_utterance_string = $target_utterance->verbalize;
	    my @target_utterance_components = grep { length( $_ ) && $_ !~ m/^\p{Punct}+$/ } split /$segmentation_regex_object/ , $target_utterance_string;
	    
	    map {
		$unsupported_sequences{ StringNormalizer::_normalize( $_ ) }{ $_ }++
	    } @target_utterance_components;

	}

    }

    # cluster sequences
    my $clusters = $self->_cluster_by_type( $instance_target , \%unsupported_sequences );

    return $clusters;

}

__PACKAGE__->meta->make_immutable;

1;
