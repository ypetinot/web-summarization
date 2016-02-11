package TargetAdapter::LocalMapping::SimpleTargetAdapter::MixtureSlot;

# TODO : MixtureSlot => mixture of AbstractiveSlot and WordEmbeddingSlot
# => simply create slot that has both slots undernead and combine options

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Slot' );

has '_abstractive_slot' => ( is => 'ro' , isa => 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AbstractiveSlot' ,
			     init_arg => undef , lazy => 1 , builder => '_abstractive_slot_builder' );
sub _abstractive_slot_builder {
    my $this = shift;
    return $this->_slot_builder( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AbstractiveSlot' );
}

has '_extractive_slot' => ( is => 'ro' , isa => 'TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot' ,
			     init_arg => undef , lazy => 1 , builder => '_extractive_slot_builder' );
sub _extractive_slot_builder {
    my $this = shift;
    return $this->_slot_builder( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot' );
}

sub _slot_builder {

    my $this = shift;
    my $slot_class = shift;

    # TODO : ideally I should avoid code redundancy with AdaptableSequence => create a new method ?
    my $slot_object = ( Web::Summarizer::Utils::load_class( $slot_class ) )->new(
	parent => $this->parent,
	id => $this->id,
	key => $this->key,
	# TODO : can we avoid having to explicitly pass the neighborhood ?
	neighborhood => $this->neighborhood,
	from => $this->from,
	to => $this->to,
	# TODO : provide callback to compute probability ?
	replacement_probability_only => 1
	);

    return $slot_object;
    
}

has 'mixture_ratio' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_mixture_ratio_builder' );
sub _mixture_ratio_builder {
    my $this = shift;
    my $current_filler = $this->key;
    # TODO : the appearance prior (mixture ratio) probably shouldn't be target-dependent (?)
    my $mixture_ratio = $this->neighborhood->neighborhood_density->{ $current_filler } || 0;
    return $mixture_ratio;
}

sub mix {
    my $this = shift;
    my $component_1 = shift;
    my $component_2 = shift;
    my $mixture_ratio = $this->mixture_ratio;
    return $mixture_ratio * $component_1 + ( 1 - $mixture_ratio ) * $component_2;
}

sub appearance_prior {
    my $this = shift;
    my $candidate = shift;
    $this->mix( map { $_->appearance_prior( $candidate ) } ( $this->_abstractive_slot , $this->_extractive_slot ) );
}

sub process {

    my $this = shift;

    my %_options;
    my %_id_2_object;
    my $mixture_ratio = $this->mixture_ratio;

    foreach my $entry ( [ 1 - $mixture_ratio , $this->_extractive_slot ] ,
			[ $mixture_ratio , $this->_abstractive_slot ] ) {
    
	my $basic_slot_option_weight = $entry->[ 0 ];
	if ( $basic_slot_option_weight ) {
	    my $basic_slot_options = $entry->[ 1 ]->process;
	    map {
		my $basic_slot_option = $_;
		my $basic_slot_option_token = $basic_slot_option->[ 0 ];
		my $basic_slot_option_token_id = $basic_slot_option_token->id;
		my $basic_slot_option_probability = $basic_slot_option->[ 1 ];
		$_options{ $basic_slot_option_token_id } += $basic_slot_option_weight * $basic_slot_option_probability;
		$_id_2_object{ $basic_slot_option_token_id } = $basic_slot_option_token;
	    } @{ $basic_slot_options };
	}

    }

    my @options = map { [ $_id_2_object{ $_ } , $_options{ $_ } ] } keys( %_options );

    return \@options;
    
}

__PACKAGE__->meta->make_immutable;

1;
