package TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptableSequence;

use strict;
use warnings;

use TargetAdapter::Extractive::Analyzer;

use Carp::Assert;
use Function::Parameters qw/:strict/;
use List::MoreUtils qw/uniq/;

use Moose;
use namespace::autoclean;

with( 'DMOZ' );
with( 'Logger' );
with( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Span' );

# parent
has 'parent' => ( is => 'ro' , isa => __PACKAGE__ , predicate => 'has_parent' );

# target
has 'target' => ( is => 'ro' , isa => 'Category::UrlData' , lazy => 1 , builder => '_target_builder' );
sub _target_builder {
    my $this = shift;
    return $this->parent->target;
}

# slots (replacement for _slots ?)
has 'slots' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_slots_builder' );
sub _slots_builder {
    my $this = shift;
    $this->template_structure;
    my @slots = values( %{ $this->_slots } );
    return \@slots;
}

# slots
# TODO : rename
has '_slots' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# analyzer
has analyzer => ( is => 'ro' , isa => 'TargetAdapter::Extractive::Analyzer' , init_arg => undef , lazy => 1 , builder => '_analyzer_builder' );
sub _analyzer_builder {
    my $this = shift;
    return new TargetAdapter::Extractive::Analyzer;
}

# reference specific data
has 'reference_specific' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => '_reference_specific_builder' );
sub _reference_specific_builder {
    my $this = shift;
    return $this->_mirrored_analysis->[ 1 ];
}

# target specific data
has 'target_specific' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => '_target_specific_builder' );
sub _target_specific_builder {
    my $this = shift;
    return $this->_mirrored_analysis->[ 0 ];
}

# CURRENT : can this be moved to the neighborhood object ?
has '_mirrored_analysis' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_mirrored_analysis_builder' );
sub _mirrored_analysis_builder {
    my $this = shift;    
    my $original_sentence_object = $this->original_sequence->object;
    
    #my ( $target_specific , $reference_specific ) = $this->extractive_analyzer->mutual( $this->target , $original_sentence_object , target_threshold => $this->support_threshold_target , reference_threshold => 1 );
    my ( $target_specific , $reference_specific ) = $this->neighborhood->mutual( $this->target , $original_sentence_object , instance_1_threshold => $this->support_threshold_target , instance_2_threshold => 1 );

    return [ $target_specific , $reference_specific ];

}

# original sequence
has 'original_sequence' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 1 );

# target supported
has 'target_supported' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_target_supported_builder' );
sub _target_supported_builder {
    my $this = shift;
    my $unsupported = scalar( grep { ! $this->target_support->[ $_ ] } @{ $this->_range_sequence } );
    return $unsupported ? 0 : 1 ;
}

# support threshold for the target
has 'support_threshold_target' => ( is => 'ro' , isa => 'Num' , required => 1 );

# target support
has 'target_support' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_target_support_builder' );
sub _target_support_builder {

    my $this = shift;

    if ( $this->has_parent ) {
	return $this->parent->target_support;
    }

    my @target_support = map {
	
	my $original_token = $this->original_sequence->object_sequence->[ $_ ];
	$original_token->is_punctuation ? 1 :
	    ( ( $this->target->supports( $original_token ) > $this->support_threshold_target ) || 0 );
	
    } @{ $this->_range_sequence };

    return \@target_support;

}

# main entity
has 'main_entity' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_main_entity_builder' );
sub _main_entity_builder {
    my $this = shift;
    
    # 1 - get list of target specific strings
    my @target_sequences = keys( %{ $this->target_specific->raw_sequences } );

    # 2 - count modality occurrences
    my %sequence_2_count;
    map {
	foreach my $modality ( $this->target->title_modality , $this->target->url_modality , $this->target->content_modality ) {
	    my $modality_support = $modality->supports( $_ , regex_match => 1 );
	    if ( $modality_support ) {
		$sequence_2_count{ $_ }++;
	    }
	}
    } @target_sequences;
    
    # 3 - return top ranked entity if it appears at least in two modalities
    my @sorted_sequences = sort { $sequence_2_count{ $b } <=> $sequence_2_count{ $a } } grep { defined( $sequence_2_count{ $_ } ) && ( $sequence_2_count{ $_ } >= 2 ) } @target_sequences;
    my $main_entity = scalar( @sorted_sequences ) ? $sorted_sequences[ 0 ] : '__MAIN_ENTITY__';

    return $main_entity;

}

sub original_substring {
    my $this = shift;
    my $index_from = shift;
    my $index_to = shift;
    my $substring = join( ' ' , map { $this->original_sequence->object_sequence->[ $_ ]->surface } uniq ( $index_from .. $index_to ) );
    return $substring;
}

sub mark_status {
    my $this = shift;
    my $from = shift;
    my $to  = shift;
    my $status = shift;
    map { $this->_status->[ $_ ] = $status } uniq ( $from .. $to );
}

sub is_supported {
    my $this = shift;
    my $index = shift;
    return ( $this->get_status( $index ) eq $this->status_supported ) || 0;
}

sub mark_supported {
    my $this = shift;
    $this->mark_status( @_ , $this->status_supported );
}

sub mark_function {
    my $this = shift;
    $this->mark_status( @_ , $this->status_function );
}

sub mark_slot {

    my $this = shift;
    my $from = shift;
    my $to = shift;
    my $slot_marker = shift || "__SLOT__";
    
    # test status of the target span
    my %span_status;
    map { $span_status{ $this->_status->[ $_ ] }++ } ( $from .. $to );
    my @span_statuses = keys( %span_status );
    if ( ( $#span_statuses != 0 ) || ( $span_statuses[ 0 ] ne $this->status_original ) ) {
	print STDERR "Invalid configuration ...\n";
    }

    my $slot_id = $this->get_new_slot_id;
    
    # TODO : can we do better ? (re)combine with create_slot ?
    # place holder for slot
    #my $slot_object = join( '' , $slot_marker , $slot_id );
    my $slot_object = $slot_marker;
    $this->_slots->{ $slot_id } = $slot_object;
    map {
	$this->_status->[ $_ ] = $slot_id;
    } uniq ( $from .. $to );

    return $slot_id;

}

sub get_slot_at {
    my $this = shift;
    my $index = shift;
    return $this->_slots->{ $this->get_status( $index ) };
}

sub get_new_slot_id {
    
    my $this = shift;
    my $slot_id = scalar( keys( %{ $this->_slots } ) );

    return $slot_id

}

method create_slot ( :$from , :$to , :$slot_class , :$key , :$id = undef ) {

    # generate slot id
    if ( ! defined( $id ) ) {
	$id = $self->get_new_slot_id;
    }

    affirm { ( ! $self->is_in_slot( $from ) ) || ( $self->get_status( $from ) == $id ) } 'Slot id and marked id must agree' if DEBUG;

    # (re)mark slot
    map { $self->_status->[ $_ ] = $id } uniq ( $from .. $to );

    my $slot_object = ( Web::Summarizer::Utils::load_class( $slot_class ) )->new(
	parent => $self,
	id => $id,
	key => $key,
	# TODO : can we avoid having to explicitly pass the neighborhood ?
	# Note : the neighborhood needs to be available somehow for trainable slots
	neighborhood => $self->neighborhood,
	from => $from,
	to => $to
	);

    # register slot
    $self->_slots->{ $id } = $slot_object;

    return $slot_object;

}

# start/end nodes
has 'start_node' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => '<s>' );
has 'end_node' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => '</s>' );

has 'status_abstractive' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'a' );
has 'status_control' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'c' );
has 'status_function' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'f' );
has 'status_original' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'o' );
has 'status_supported' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 's' );
has 'status_reference_specific' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'r' );

# status
# o => original token
# s => supported
# f => function
# %n => id of the slot controlling this token
has '_status' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_status_builder' );
sub _status_builder {
    my $this = shift;
    my @token_statuses = map {
	$this->status_original
    } @{ $this->original_sequence->object_sequence };
    return \@token_statuses;
}

# TODO : support via a trait
sub get_status {
    my $this = shift;
    my $index = shift;
    return $this->_status->[ $index ];
}

sub is_in_slot {
    my $this = shift;
    my $index = shift;
    return ( $this->get_status( $index ) =~ m/^\d+$/ );
}

sub is_controlled {
    my $this = shift;
    my $index = shift;
    return ( $this->_status->[ $index ] ne $this->status_original );
}


# order
has 'order' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_order_builder' );
sub _order_builder {
    my $this = shift;
    my $order = scalar(  grep { ! $_->is_punctuation } map { $this->original_sequence->object_sequence->[ $_ ] } ( $this->from .. $this->to ) );
    return $order;
}

sub seek_and_adapt_wrapper {

    my $this = shift;

    my @reference_specific_orders = sort { $b <=> $a } @{ $this->reference_specific->get_orders };
    foreach my $reference_specific_order (@reference_specific_orders) {

	# Note : we only adapt string sub-strings of the current sequence
	# TODO : would it make sense to adapt the full sequence ?
	if ( $reference_specific_order >= $this->order ) {
	    next;
	}
	
	# 1 - get all sequences for the current order
	my $order_sequences = $this->reference_specific->get_order_sequences( $reference_specific_order );
	
	# 2 - check for each order sequence whether is appears in the reference summary
	foreach my $order_sequence (@{ $order_sequences }) {
	    
	    # proceed recursively from this point onward
	    $this->seek_and_adapt( $reference_specific_order , $order_sequence );
	    
	}

    }

}

# recursive adaptation
sub seek_and_adapt {

    my $this = shift;
    my $order = shift;
    my $sequence = shift;

    my @sequence_tokens = split /\s+/ , $sequence;

    for ( my $i = $this->from ; $i <= $this->to ; $i++ ) {

	my $ok = 1;
	my $from = $i;
	my $to = $from;
	my $tokens_seen = 0;

	my @buffer;
	while ( $ok && ( $tokens_seen < $order ) && ( $to <= $this->to ) ) {

	    # skip if the current location is controlled already
	    if ( $this->is_controlled( $to ) ) {
		$ok = 0;
		last;
	    }

	    my $original_token = $this->original_sequence->object_sequence->[ $to++ ];
	    push @buffer , $original_token;

	    if ( $original_token->is_punctuation ) {
		if ( $tokens_seen ) {
		    next;
		}
		else {
		    # moving on to the next position, no need to start a slot with punctuation
		    last;
		}
	    }
	    
	    my $order_sequence_token = $sequence_tokens[ $tokens_seen++ ];
	    my $original_token_regex = $original_token->as_regex;
	    if ( $order_sequence_token !~ m/$original_token_regex/ ) {
		$ok = 0;
	    }

	}
	
	if ( ! $ok || ( $tokens_seen != $order ) ) {
	    # no match, moving ahead to the next position in the original sequence
	    next;
	}
	
	# TODO : can avoid this somehow ?
	$to--;

	# check whether the currenr sub-sequence is fully supported
	if ( ! $this->target_supported ) {
	    
            # we have a matching sub-sequence
	    $this->logger->debug( "Found match for <$order/$sequence> : $from -- $to" );
	    my $slot = $this->mark_slot( $from , $to );
	
	}

    }

}

__PACKAGE__->meta->make_immutable;

1;
