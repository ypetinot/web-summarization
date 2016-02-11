package WordGraph::Node::Slot;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'WordGraph::Node';

# (true/fork) slot fillers (when relevant)
has 'fillers' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } , lazy => 1 );

# filler candidates
has 'filler_candidates' => ( is => 'rw' , isa => 'HashRef[ArrayRef]' , default => sub { {} } );

# filler features
has 'filler_features' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# Set slot filler
sub set_slot_filler {

    my $this = shift;
    my $label = shift;
    my $filler = shift;

    # first make sure we're not overwriting an existing filler
    if ( defined( $this->fillers()->{ $label } ) ) {
	die "Attempting to overwrite existing filler for $label ...";
    }

    $this->fillers()->{ $label } = $filler;

}

# Is there a more Moose-ish way of triggering data generation (for a HashRef) ?
sub _generate_filler_data {

    my $this = shift;
    my $instance = shift;

    my $instance_url = $instance->url();

    my %filler_candidates;
    
    # 1 - make sure we have the full list of instance fillers available
    my $instance_fillers = $this->graph()->data_extractor()->collect_instance_fillers( $instance );

    # 2 - collect fillers for the target node
    foreach my $instance_filler (@{ $instance_fillers }) {
	
	# a filler candidate cannot appear as a regular node in the graph (makes sense)
	# TODO: allow full ngram lookup ?
	if ( scalar( @{ $this->graph()->get_nodes_by_surface( $instance_filler ) } ) ) {
	    # do nothing
	    next;
	}

	my $filler_confidence = $this->filler_confidence( $instance_filler );
	if ( $filler_confidence ) {
	    
	    my $filler_features = $this->graph()->data_extractor()->generate_filler_features( $instance , $instance_filler );
	    $filler_candidates{ $instance_filler } = $filler_features;
	    
	}
	
    }
    
    # store in cache
    $this->filler_candidates()->{ $instance_url } = \%filler_candidates;
    
    return \%filler_candidates;

}

sub get_filler_candidates {

    my $this = shift;
    my $instance = shift;

    my $instance_url = $instance->url();

    if ( ! defined( $this->filler_candidates()->{ $instance_url } ) ) {
	$this->_generate_filler_data( $instance );
    }

    return $this->filler_candidates()->{ $instance_url };

}

sub get_filler_features {

    my $this = shift;
    my $instance = shift;

    my $instance_url = $instance->url();

    # surface --> features
    # Note: the surface might be a candidate value (i.e. we are dealing with a clone node)
    my $filler_value = $this->fillers()->{ $instance_url } || '';
    if ( ! defined( $filler_value ) ) {
	die "Missing filler value for $this / $instance_url ...";
    }

    # filler features should be cached here ..
    if ( ! defined( $this->filler_candidates()->{ $instance_url } ) ) {
	$this->_generate_filler_data( $instance );
    }

    my $filler_features = $this->filler_candidates()->{ $instance_url }->{ $filler_value } || {};

    return $filler_features;

}

# filler confidence
sub filler_confidence {

    my $this = shift;
    my $filler = shift;

    # TODO: should Node directly support abstract_type ?
    # TODO: create constants for SLOT_ADJECTIVE and SLOT_ADVERB
    if ( $this->token->abstract_type eq 'SLOT_ADJECTIVE' || $this->token->abstract_type eq 'SLOT_ADVERB' ) {

	my @filler_tokens = split /\s+/, $filler;
	# Only support adjective/adverbs that consist of a single word
	if ( scalar(@filler_tokens) > 1 ) {
	    return 0;
	}

	# look-up adjective/adverb against dictionary (only known adjective/adverbs are acceptable)
	# TODO

    }

    return 1;

}

# get realized form
sub realize {

    my $this = shift;
    my $instance = shift;

    # We default to the original filler value for this slot
    # Not very useful, but allow to compare (non-extractive) Filippova to a system that attemps to extract relevant slot values
    my $surface = $this->SUPER::realize( $instance );

    my $instance_url = $instance->url();
    my $filler_value = $this->fillers()->{ $instance_url };
    if ( defined( $filler_value ) ) {
	print STDERR "Got slot filler for $this / $instance_url : $filler_value\n";
	$surface = $filler_value;
    }
    else { # we're probably dealing with a test instance, however this should *NOT* happen !
	print STDERR "Missing slot filler for $this / $instance_url ...\n";
	$surface = "[__WORDGRAPH_SLOT_MISSING_FILLER__]";
    }

    return $surface;

}

# get realized form for debugging purposes
sub realize_debug {

    my $this = shift;
    my $instance = shift;

    return $this->id() . "[" . $this->realize( $instance ) . "]";

}

sub fork {

    my $this = shift;
    my $instance = shift;
    my $fork_surface = shift;

    my $instance_url = $instance->url();
    my $fork_fillers = $this->get_filler_candidates( $instance );

    my @forks;
    foreach my $fork_filler (keys %{ $fork_fillers }) {

	# clone current node
	my $forked_slot = $this->clone();

	# set fork filler
	$forked_slot->fillers()->{ $instance_url } = $fork_filler;

	### # treat filler confidence as a feature
	### $filler_features->{ $FEATURE_SLOT_FILLER_CONFIDENCE } = $candidate_filler->[ 1 ];
	
	# set filler features for this fork
	my $fork_features = $fork_fillers->{ $fork_filler };
	$forked_slot->filler_features()->{ $instance_url } = $fork_features;
	
	push @forks, $forked_slot;
    
    }

    return \@forks;

}

__PACKAGE__->meta->make_immutable;

1;
