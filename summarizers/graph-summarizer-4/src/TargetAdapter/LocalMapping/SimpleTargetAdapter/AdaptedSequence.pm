package TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence;

# CURRENT : score as expected support value ?

use strict;
use warnings;

# TODO : turn slot type into a configuration parameter

use Similarity;
use TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::OptionsSegment;
use TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::BosMarkerSegment;
use TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::EosMarkerSegment;
use Vector;

use Algorithm::Munkres;
use Carp::Assert;
use Function::Parameters qw/:strict/;
use Graph::Writer::Dot;
use JSON;
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;
use Statistics::Basic qw/:all/;
use Text::Levenshtein::XS qw/distance/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::ScanningAdaptableSequence' );

# Perform replacements only ? (i.e. no LM to control transitions)
has 'do_replacement_only' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# Perform compression ?
has 'do_compression' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# Write graph ?
has 'do_write_graph' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# Output learning data ?
has 'output_learning_data' => ( is => 'ro' , isa => 'Bool' , default => 0 );

has 'component_dependencies' => ( is => 'ro' , isa => 'Graph::Directed' , init_arg => undef , lazy => 1 , builder => '_component_dependencies_builder' );
sub _component_dependencies_builder {
    my $this = shift;
    return $this->original_sequence->dependencies_graphs->[ $this->component_id ]->[ 0 ];
}

sub is_edge_conjunction {
    my $dependency_graph = shift;
    my $edge = shift;
    my $edge_type = $dependency_graph->get_edge_attribute( @{ $edge } , 'dependency-type' );
    my $is_edge_conjunction = ( $edge_type eq 'appos' || $edge_type =~ m/conj_/ );
    return $is_edge_conjunction;
}

has 'component_dependencies_disconnected' => ( is => 'ro' , isa => 'Graph::Directed' , init_arg => undef , lazy => 1 , builder => '_component_dependencies_disconnected_builder' );
sub _component_dependencies_disconnected_builder {

    my $this = shift;
    my $component_dependencies = $this->component_dependencies;
    # TODO : is a deep copy absolutely necessary ?
    my $component_dependencies_disconnected = $component_dependencies->deep_copy;

    my %equivalence_class_to_parent;

    foreach my $edge ( $component_dependencies->edges ) {

	if ( is_edge_conjunction( $component_dependencies , $edge ) ) {
	
	    my $edge_from = $edge->[ 0 ];
	    my $edge_to = $edge->[ 1 ];
	    
	    if ( ! defined( $equivalence_class_to_parent{ $edge_from } ) ) {
		
		# Note : we have found a new list / "equivalence class"
		my @equivalence_list = ( $edge_from );
		my %final_class;
		while( scalar( @equivalence_list ) ) {
		    
		    my $current_node = shift @equivalence_list;
		    $final_class{ $current_node }++;

		    # 1 - follow all appos/conj dependencies starting or ending at this node
		    my @conj_edges = grep {
			is_edge_conjunction( $component_dependencies , $_ );
		    } $component_dependencies->edges_at( $current_node );
			
		    # 2 - register all nodes found
		    map {
			foreach my $edge_node (@{ $_ }) {
			    if ( ! $final_class{ $edge_node }++ ) {
				# Note : we have found a new node, schedule expansion
				push @equivalence_list , $edge_node;
			    }
			}
			# Note : we know about this edge, we can remove it
			$component_dependencies_disconnected->delete_edge( @{ $_ } );
		    } @conj_edges;			

		}
		
		# Note : for each element in the final class we look for a parent node that is not in the class
		# => there should be only one such node (?)
		my %class_parents;
		map {
		    my @node_parents = $component_dependencies_disconnected->predecessors( $_ );
		    foreach my $node_parent (@node_parents) {
			$class_parents{ $node_parent }++;
		    }
		} keys( %final_class );
		
		my @all_class_parents = keys( %class_parents );
		my $n_class_parents = scalar( @all_class_parents );
		if ( $n_class_parents != 1 ) {
		    $this->logger->warn( "The disconnected dependency graph should be a tree : there is more than one parent for a dependency-based equivalence class => $n_class_parents" );
		}

		foreach my $class_parent (@all_class_parents) {

		    # Note : we create an edge between the parent of the source node and each member of the equivalence class
		    map {
			$component_dependencies_disconnected->add_edge( $class_parent , $_ );
			$equivalence_class_to_parent{ $_ } = $class_parent;
			# TODO : should we replicate edge attributes ?
		    } keys( %final_class );
		    
		}

	    }

	    # TODO : are there additional cases that require the creation of new edges ?

	}
    }
    return $component_dependencies_disconnected;
}

# token 2 segment mapping (ids)
has '_token_2_segment' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# segment 2 tokens mapping (ids)
has '_segment_2_tokens' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

sub _transition_probability {

    my $this = shift;
    my $from_token = shift;
    my $to_token = shift;

    my ( $_from , $_to ) = map {
	ref( $_ ) ? $_->surface : $_;
    } ( $from_token , $to_token );

    # we cannot repeat the same token
    # TODO : this should really be the result of the language score being low/zero
    if ( $_from eq $_to ) {
	return 0;
    }

    my $count_from = $this->global_data->global_count( 'summary' , 1 , $_from );
    my $count_from_to = $this->global_data->global_count( 'summary' , 2 , join( ' ' , $_from , $_to ) );

    # Note : probability of relevant if the slot is not filled
    return $count_from ? $count_from_to / $count_from : 0;

    # TODO : create subclass for Viterbi adaptation => specific top level TargetAdapter class => HungarianTargetAdapter
    # => problem is that this would prevent immediate comparisons between different decoding algorithms ?
    # TODO - Kapil : Following arcs => jump to potential POS tags

}

# symbol - removal
has 'symbol_removal' => ( is => 'ro' , isa => 'Str' , default => '<remove>' );

# node ids
has '_node_2_id' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );
has '_id_2_node' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );
sub _get_node_id {
    my $this = shift;
    my $node = shift;
    if ( ! defined( $this->_node_2_id->{ $node } ) ) {
	# Note : no need to add a unique identifier beyond the node ref
        #my $id = join( ":::" , scalar(@segments) , $node );
	my $id = '' . $node;
	$this->_id_2_node->{ $id } = $node;
	$this->_node_2_id->{ $node } = $id;
    }
    return $this->_node_2_id->{ $node };
}

sub _get_node {
    my $this = shift;
    my $id = shift;
    # Note : guaranteed to exist since we reaching this point *after* the decoding graph has been constructed
    return $this->_id_2_node->{ $id };
}

my $SEGMENT_TYPE_MARKER_BOS = 1;
my $SEGMENT_TYPE_MARKER_EOS = 2;
my $SEGMENT_TYPE_REGULAR = 3;

has '_segments' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_segments_builder' );
sub _segments_builder {

    my $this = shift;

    # TODO : directly make this ($from - 1) ?
    my $from = $this->from;
    my $to = $this->to + 1;
    
    my @segments;
    my @ancestors;
    
    for ( my $i = ( $from - 1 ) ; $i <= $to ; $i++ ) {
	
	my $token;
	my $token_original;
	my $status;
	my $prior = 1;
	my $segment_end = $i;
	my $segment_type;

	# CURRENT : check graph for cases where shortest path is empty
	
	if ( $i == ( $from - 1 ) ) {
	    $token = $this->start_node;
	    $status = $this->status_control;
	    $segment_type = $SEGMENT_TYPE_MARKER_BOS;
	}
	elsif( $i == $to ) {
	    $token = $this->end_node;
	    $status = $this->status_control;
	    $segment_type = $SEGMENT_TYPE_MARKER_EOS;
	}
	else {
	    $token = $this->original_sequence->object_sequence->[ $i ];
	    $status = $this->get_status( $i );
	    $prior = $this->priors->[ $i ];
	    $segment_type = $SEGMENT_TYPE_REGULAR;
	}

	# keep track of the original token
	$token_original = $token;
	
	# generate options
	# => the approach is to use the prior as an estimate for probability of appearance
	my @options;
	
	# compute emission options and their associated probabilities
	# TODO : add threshold parameter here ?
	if ( $status eq $this->status_control ) {
	    push @options , [ $token , 1 ];
	}
	# TODO : add status for punctuation ?
	elsif ( $token->is_punctuation ) {
	    push @options , [ $token , 1 ];
	}
	elsif ( $status eq $this->status_supported ) {
	    # CURRENT : we need to impose the presence of some tokens => supported tokens
	    # => otherwise an empty sentences will generally be preferred
	    push @options , [ $token , 1 ];
	}

=pod
	    
	    # Note : there is probably no need for two status => the notion of support is necessarily probabilistic
	    
	    # CURRENT : the rest of the emission probability should be allocate to siblings in the type hierarchy => slot like behavior => add flag to activate this option (abstractive adaptation)
	    # TODO : only consider siblings that appear in the neighborhood ?
	    # TODO : use similarity between target and reference to weight prior => kernel

    my ( $type_conditional_probability , $_token_types ) = $this->analyzer->type_conditional_probability( $this->target , $token );
	    
	# => i.e. what does it mean to have a 0 prior and not be in a slot => abstractive term
	# => guaranteed removal means you add the parent token
	
	# TODO : if in abstractive mode - look for replacements based on type but without explicit target support
	if ( $original_emission_probability < 1 && $this->do_abstractive_replacements && scalar( @{ $token_types } ) ) {
	my $abstractive_replacement_probability = 1 - $original_emission_probability;
		
	# we look for potential replacements that are not directly observed in the target
	my $type_siblings = $this->analyzer->type_siblings( $token_types );
		
	# CURRENT : the distribution of type siblings must sum to 1
		
	foreach my $type_sibling (@{ $type_siblings }) {
		    
	my $type_sibling_surface = $type_sibling;
	
	# compute support probability by target
	my $target_appearance_probability = $this->_conditional_appearance_probability( $type_sibling_surface );
	
	# TODO : add probability as a field in Web::Summarizer::Token ?
	my $type_sibling_token_probability = $abstractive_replacement_probability * $target_appearance_probability;
	    
	# TODO => emission probability should be conditional probability of surface string given associated type in target
	
	# Note : the assumption is that token is central to the reference for the set of detected types
	# => soften this ? => i.e. compute type_conditional_probability of token for the reference ? => divergence/joint probability
	# TODO : maybe use KL divergence of source/replacement as feature for slot filling ?

=cut

	# TODO : is this the best way to test for slot control ?
	elsif ( ! $this->is_in_slot( $i ) ) {
	    push @options , [ $token , 1 ];
	}
	else { # Note : slots - must have been pre-marked based on n-gram analysis (?)
	    
	    # CURRENT : is there a way to handle slots in a way that is not based on deterministic matching ?
	    # => should it not be deterministic ?
	    
	    # TODO : apply prior to slot as well
	    my $slot = $this->_slots->{ $status };
	    
	    # generate all possibilities for this slot (this is a recursive process)
	    my $slot_options = $slot->generate_options( $this->target );
	    push @options , @{ $slot_options };
	    
	    # CURRENT : confirm that the slot actually ends on its last token's index
	    $segment_end = $slot->to;
	    
	    # for slots we use the key as an indication of the original token
	    $token_original = $slot->key;

	}

	if ( ! scalar( @options ) ) {
	    $this->logger->error( "Reaching point with no options => decoding might fail" );
	}
	
	# update segments
	my $segment_object = undef;
	my $segment_id = $#segments + 1;
	if ( $segment_type == $SEGMENT_TYPE_MARKER_BOS ) {
	    $segment_object = new TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::BosMarkerSegment( parent => $this , token_id => $i , id => $segment_id );
	}
	elsif ( $segment_type == $SEGMENT_TYPE_MARKER_EOS ) {
	    $segment_object = new TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::EosMarkerSegment( parent => $this , token_id => $i , id => $segment_id );
	}
	else {
	    $segment_object = new TargetAdapter::LocalMapping::SimpleTargetAdapter::Segment::OptionsSegment (
		original => $token_original ,
		options => \@options ,
		from => $i , to => $segment_end ,
		# TODO : this probably does not belong here
		neighborhood => $this->neighborhood ,
		parent => $this ,
		id => $segment_id
		);
	}

	push @segments , $segment_object;
	
	my @token_span = uniq ( $i .. $segment_end );

	# TODO : store in segment object instead ?
	# update token 2 segment mapping
	map { $this->_token_2_segment->{ $_ } = $segment_id } @token_span;

	# TODO : store in segment object instead ?
	# update segment 2 tokens mapping
	$this->_segment_2_tokens->{ $segment_id } = \@token_span;

	# update position (no effect unless we were dealing with a slot)
	$i = $segment_end;
	
    }

    return \@segments;

}

our $PREP_DEPENDENCY_CONNECTOR_WITH = 'with';

method finalize_hungarian( :$compressed = 0 , :$neighbors = [] ) {

    # CURRENT : separate _raw_finalization_hungarian from compression ?
    my ( $_token_sequence , $_id2remove ) = @{ $self->_raw_finalization_hungarian };
    my @token_sequence = @{ $_token_sequence };
    my %id2remove = %{ $_id2remove };

    if ( $compressed ) {

=pod
	# reanalyze dependencies
	# CURRENT : generate templated_sequence to get more generic dependencies (especially dependencies that put supported tokens at the root/top of the tree)
    
##        my @templated_sequence_tokens = map {  ( $self->is_in_slot( $_ ) && ! ( ref( $self->get_slot_at( $_ ) ) =~ m/Abstractive/ ) ) ? join( '_' , 'SLOT' , $self->get_status( $_ ) ) : $self->original_sequence->object_sequence->[ $_ ]->surface } @{ $self->_range_sequence };	
##        my @templated_sequence_tokens = map {  ( $self->get_status( $_ ) eq 'f' || $self->target->supports( $self->original_sequence->object_sequence->[ $_ ] , regex_match => 1 ) ) ? $self->original_sequence->object_sequence->[ $_ ]->surface : join( '_' , 'SLOT' , $self->get_status( $_ ) ) } @{ $self->_range_sequence };

        my @templated_sequence_tokens = map { ( ( $self->priors->[ $_ ] >= 0.5 ) || $self->original_sequence->object_sequence->[ $_ ]->is_punctuation ) ? $self->original_sequence->object_sequence->[ $_ ]->surface : join( '_' , 'SLOT' , $self->get_status( $_ ) ) } @{ $self->_range_sequence };
	my $template_dependencies = $self->original_sequence->_dependency_parsing_service->get_dependencies_from_tokens( \@templated_sequence_tokens );

        # CURRENT / TODO : use this set of dependencies to build a compression graph
        # CURRENT : can function tokens always be represented as edges in this graph ?
        # Compression graph: all edges connected to a 
=cut

=pod
    p Dumper( $self->original_sequence->_dependency_parsing_service->get_dependencies( "SLOT_0 student newspaper of SLOT_1's SLOT_2 in SLOT_3." ) )
	    if ( ! $token->is_punctuation ) {
		$confidence *= $this->priors->[ $i ];
	    }
=cut

    }

=pod
	my @successors_reachable;
	my @predecessors_reachable;
	
		foreach my $neighbors_entry ( [ \@successors , 0 , \@successors_reachable ] , [ \@predecessors , 1 , \@predecessors_reachable ] ) {
		    
		    my $neighbors_entry_set = $neighbors_entry->[ 0 ];
		    my $neighbors_entry_direction = $neighbors_entry->[ 1 ];
		    my $neighbors_entry_reachable = $neighbors_entry->[ 2 ];
		    
		    map {
			
			my $dependency_from = $neighbors_entry_direction ? $_ : $original_node_id;
			my $dependency_to = $neighbors_entry_direction ? $original_node_id : $_;
			
			my $dependency_from_sequential = min( $_ , $original_node_id );
			my $dependency_to_sequential = max( $original_node_id , $_ );
			
			# type of dependency
			my $dependency_type = $this->component_dependencies->get_edge_attribute(
			    $dependency_from,
			    $dependency_to,
			    $EDGE_ATTRIBUTE_DEPENDENCY_TYPE );
			
			my $remove_neighbor = 1;
			
			if ( $dependency_type =~ m/^(.*)_(.*)$/ ) {
			    
			    my $dependency_family = $1;
			    my $dependency_connector = $2;
			    
			    my $remove_connector = 0;
			    
			    # Note : removing prepositions who have the slot as their parent
			    elsif ( $dependency_family eq 'prep' ) {
				# TODO : can we do better ? is this always true ?
				$remove_connector = 1;
				$remove_neighbor = 1;
			    }
			    
			    if ( $remove_connector ) {
				my @connector_indices = grep { $this->original_sequence->object_sequence->[ $_ ]->id eq $dependency_connector } ( $dependency_from_sequential .. $dependency_to_sequential );
				my $connector_indices_count = scalar( @connector_indices );
				if ( $connector_indices_count ) {
				    
				    if ( $connector_indices_count > 1 ) {
					$this->logger->debug( "Found multiple connectors between $dependency_from and $dependency_to for dependency $dependency_type : " . join( ' // ' , @connector_indices ) );
				    }
				    
				    # we find the connector that is closest to the current node
				    my $connector_index = ( $_ > $original_node_id ) ? $connector_indices[ 0 ] : $connector_indices[ $#connector_indices ];
				    # Note : we delay the removal until we actually decide to remove the slot node itself
				    
				}
			    }
			    
			}
			elsif ( $dependency_type eq 'appos' ) {
			    # Note : appos dependencies are fundamentally equivalent to conj_* dependencies
			    # Note : we don't care about potential punctuation connectors here (they will be handled at realization time)
			    $remove_neighbor = 0;
			}
			else {
			    # Note : we probably don't need to worry about other kinds of dependencies
			}
			
			if ( $remove_neighbor ) {
			    push @{ $neighbors_entry_reachable } , $_;
			}
			
		    } @{ $neighbors_entry_set };
		    
		}

		# ************************************************************************************************************************************************************
		# parent(s)-based handling
		# ************************************************************************************************************************************************************
		
		my $dependency_types_modifier = 0;
		my @dependency_types = map {
		    my $dependency_type = $this->component_dependencies->get_edge_attribute( $_ , $original_node_id , $EDGE_ATTRIBUTE_DEPENDENCY_TYPE );
		    if ( $dependency_type =~ m/mod$/ ) {
			$dependency_types_modifier++;
		    }
		    $dependency_type;
		} @predecessors_reachable;
		if ( $dependency_types_modifier == scalar( @dependency_types ) ) {
		    # TODO : this is not valid if we choose to reinstate the slot (should that even be allowed if the situation is handled by the appearance function ?)
		    $id2remove{ $original_node_id }++;
		}
		elsif ( scalar( @dependency_types ) == 1 ) {
		    
		    my $dependency_type = $dependency_types[ 0 ];
		    if ( $dependency_type =~ m/^prep_(.*)$/ ) {
			
			my $dependency_connector = $1;
			if ( $dependency_connector eq $PREP_DEPENDENCY_CONNECTOR_WITH ) {
			    
			    # determine prep edge index
			    my $edge_index = min( $original_node_id , @dependents ) - 1 ;
			    
			    if ( ( $edge_index >= 0 ) && ( $this->original_sequence->object_sequence->[ $edge_index ]->id eq $PREP_DEPENDENCY_CONNECTOR_WITH ) ) {
				
				map {
				    $id2remove{ $_ }++;
				} ( $original_node_id , $edge_index , @dependents );
				
				}
			    
			}
			
		    }
		    elsif ( $dependency_type eq 'nn' ) {
			
			# Note : this amount to simplifying an NN
			$id2remove{ $original_node_id }++;
			
		    }
		    
		}
		
		# TODO : can I come up with something cleaner ?
		if ( ! $reinstate ) {
		    $id2remove{ $original_node_id }++;
		}
		
		# ************************************************************************************************************************************************************
		
		# TODO : make sure named entities are capitalized according to their most frequent surface form => make sure tokens are always created with their most likely surface form
		# TODO : custom dependency algorithm so that unfillable slots could be naturally detached from the dependecy tree without any branch left hanging ?
		# TODO : if the slot cannot be dropped, we need to find a way to abstract it up ?
		if ( ! defined( $id2remove{ $original_node_id } ) ) {
		    $this->logger->debug( "Will not remove slot node : $original_node_id" );
		}
=cut

    # ****************************************************************************************************************************

    my @token_sequence_final;
    my $score = 1;
    my $previous_token_is_connector = 0;
    for ( my $i = 0 ; $i <= $#token_sequence ; $i++ ) {

	my $current_token_entry = $token_sequence[ $i ];
	my $current_token = $current_token_entry->[ 0 ];
	my $current_token_probability = $current_token_entry->[ 1 ];
	my $current_token_appearance = $current_token_entry->[ 2 ];
	my $current_token_index = $self->component_index( $i - 1 );
	my $current_token_is_connector = ( ! $current_token->is_special ) && ( ! $current_token->is_punctuation ) && ( ! $self->component_dependencies->has_vertex( $current_token_index ) );

	if ( $compressed ) {
	    
	    if ( ! $current_token_appearance ) {
		next;
	    }
	    elsif ( $current_token->is_punctuation && $previous_token_is_connector ) {
		pop @token_sequence_final;
		# TODO : do we need to update the score ?
	    }	    
	    # Note: the last token is the end of sequence marker
	    elsif ( $i == ( $#token_sequence - 1 ) && $current_token_is_connector ) {
		next;
	    }
###	    elsif ( $current_token_is_connector && ! defined( $connectors_keep{ $current_token_index } ) ) {
##		next;
###	    }

	}

	if ( ! $compressed && $current_token->surface =~ m/^SLOT/ ) {
	    push @token_sequence_final , $self->original_sequence->object_sequence->[ $current_token_index ];
	}	    
	elsif ( ( ! $compressed ) || ( ! defined( $id2remove{ $current_token_index } ) ) ) {
	    push @token_sequence_final , $current_token;
	    $score *= $current_token_probability;
	    $previous_token_is_connector = $current_token_is_connector;
	}
	else {
	    $self->logger->debug( "Removing node: " . $current_token->surface . " ( $current_token_probability )" );
	}

    }

    return ( \@token_sequence_final , $score );

}

has 'connector_data' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_connector_data_builder' );
sub _connector_data_builder {

    my $this = shift;

    my @connectors = map {
	[ $_ , $this->original_sequence->object_sequence->[ $_ ]->id ];
    } grep {
	$this->original_sequence->is_connector( $_ );
    } ( 0 .. ( $this->original_sequence->length - 1 ) );
    
    my %connectors_data;
    map {
	
	my $connector_index = $_->[ 0 ];
	my $connector_token_surface = $_->[ 1 ];
	
	# 2 - find all dependencies that may involve this connector
	my @matching_dependency_edges =
###	    grep {
###	    !defined( $id2remove{ $this->component_index( $_->[ 1 ] ) } ) && !defined( $id2remove{ $this->component_index( $_->[ 2 ] ) } );
###    }
	    grep {
		( $connector_index > $_->[ 1 ] ) && ( $connector_index < $_->[ 2 ] );
	} @{ $this->_connector_to_sorted_dependencies->{ $connector_token_surface } || [] };
	
	if ( scalar( @matching_dependency_edges ) ) {
	    # Note : a single connector instance may be used to link multiple pairs of tokens
	    $connectors_data{ $connector_index } = \@matching_dependency_edges;
	}
	
    } @connectors;

    return \%connectors_data;

}

has '_raw_finalization_hungarian_assignments' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_raw_finalization_hungarian_assignments_builder' );
sub _raw_finalization_hungarian_assignments_builder {
    
    my $this = shift;
    
    my @segments = @{ $this->_segments };

    # 1 - generate cost matrix
    # => map each unique filler to unique numerical id
    my @costs;
    my %original_id2numerical;
    my @original_holder_numerical_ids;
    my %id2numerical;
    my %numerical2token;
    my $max_options = -1;
    # Note : we mapping original tokens (at the segment position) to alternative tokens (at the segment position)
    for ( my $segment_id = 0 ; $segment_id <= $#segments ; $segment_id++ ) {

	# TODO : how can we avoid having to make original_as_token available for marker segments ?
	my $segment_original_holder = $segments[ $segment_id ]->original_as_token;

	# Note: what happens if we are not in a slot ?
	# Option 1 : a token that would be sometimes (not everytime) assigned to a slot should never be assigned to a slot => this is implemented in ScanningAdaptableSequence
	# Option 2 : distinct id for the non-slot version => how ?
	# => the current logic is that every single position can have variations

	my $segment_original_holder_id = ref( $segment_original_holder ) ? $segment_original_holder->id : $segment_original_holder;
	if ( ! defined( $original_id2numerical{ $segment_original_holder_id } ) ) {
	    $original_id2numerical{ $segment_original_holder_id } = scalar( keys( %original_id2numerical ) );
	}
	my $segment_original_holder_numerical_id = $original_id2numerical{ $segment_original_holder_id };
	$this->logger->debug( "Hungarian cost matrix : [$segment_id] $segment_original_holder_id >> $segment_original_holder_numerical_id" );
	# Note : represents the sequential list of global ids associated with each original segment holder
	push @original_holder_numerical_ids , $segment_original_holder_numerical_id;

	my $segment = $segments[ $segment_id ];
	foreach my $segment_option (@{ $segment->options }) {
	    
	    my $segment_option_token = $segment_option->[ 0 ];
	    my $segment_option_probability = $segment_option->[ 1 ];

	    my $segment_option_token_id = ref( $segment_option_token ) ? $segment_option_token->id : $segment_option_token ;
	    if ( ! defined( $id2numerical{ $segment_option_token_id } ) ) {
		$id2numerical{ $segment_option_token_id } = scalar( keys( %id2numerical ) );
	    }
	    my $segment_option_token_numerical_id = $id2numerical{ $segment_option_token_id };
	    $numerical2token{ $segment_option_token_numerical_id } = $segment_option_token;

	    # TODO : take into account transition costs ?
	    $costs[ $segment_original_holder_numerical_id ][ $segment_option_token_numerical_id ] = 1 - $segment_option_probability;

	    if ( $segment_option_token_numerical_id > $max_options ) {
		$max_options = $segment_option_token_numerical_id;
	    }

	}

    }

    # clean up cost metric
    # Note : the cost matrix may have less entries than the number of segments (original holders with identical surface forms are treated as a single object)
    my $n_unique_holders = scalar( keys( %original_id2numerical ) );

    # Note: is this always true ?
    affirm { $n_unique_holders - 1 <= $max_options } "There should be at least one replacement option per location - " . ( $n_unique_holders - 1 ) . " / $max_options => a location cannot be left unassigned but instead should be assigned a removal/slot marker" if DEBUG;

    for ( my $i = 0 ; $i < $n_unique_holders ; $i++ ) {
	my $segment_costs = $costs[ $i ];
	for ( my $option_id = 0 ; $option_id <= $max_options ; $option_id++ ) {
	    if ( ! defined( $costs[ $i ][ $option_id ] ) ) {
		$costs[ $i ][ $option_id ] = int( 1000000000000000 );
	    }
	}
    }

    # 2 - find optimal slot assignments
    my @optimal_assignment;
    assign(\@costs,\@optimal_assignment);

    return [ \@costs , \@optimal_assignment , \@original_holder_numerical_ids , \%numerical2token ];

}

has '_raw_finalization_hungarian' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_raw_finalization_hungarian_builder' );
sub _raw_finalization_hungarian_builder {

    # Note that the assumption is that there is a SINGLE mapping for any string (i.e. no local considerations if the string appears multiple time in the original summary)

    my $this = shift;

    my ( $_costs , $_optimal_assignment , $_original_holder_numerical_ids , $_numerical2token ) = @{ $this->_raw_finalization_hungarian_assignments_builder };
    my @costs = @{ $_costs };
    my @optimal_assignment = @{ $_optimal_assignment };
    my @original_holder_numerical_ids = @{ $_original_holder_numerical_ids };
    my %numerical2token = %{ $_numerical2token };

    # 3 - recover optimal slot assignment
    my @token_sequence;
    my %id2remove;
    my $EDGE_ATTRIBUTE_DEPENDENCY_TYPE = 'dependency-type';
    # Note : one position per segment
    for ( my $i = 0 ; $i <= $#original_holder_numerical_ids ; $i++ ) {
    
	my $original_holder_numerical_id = $original_holder_numerical_ids[ $i ];
	
	my $optimal_j = $optimal_assignment[ $original_holder_numerical_id ];
	my $segment_option = $numerical2token{ $optimal_j };
	my $segment_option_probability = 1 - $costs[ $original_holder_numerical_id ][ $optimal_j ];
	affirm { $segment_option_probability >= 0 && $segment_option_probability <= 1 } 'Segment probabilities must be in the [0,1] range' if DEBUG;

	my $appearance = 1;

	# Note : -1 to account for <s>
	# CURRENT : segment count is number of logical blocks in sequence => component_index does not account for this
	my $original_node_id = $this->component_index( $i - 1 );

	# Note : if a given position is not filled, we can determine that other positions should be dropped based on dependencies between them
	
	# => SLOT_ marks a default refiller for the slot (i.e. no refilling option is available)
	# Note : reason for not having a <remove> option is that removal of the slot token may entail the removal of dependent tokens as well
	# => disconnected set of dependents => doable
	# => for each disconnect set of dependents, consider the following options:
	# * drop slot => dependents must go as well
	# * preserve current filler and drop dependents
	# * preserve current filler and keep dependents
	# * new filler and drop dependents
	# * new filler and keep dependents
	# can we define the probability of each option ?
	# Main idea: vote of dependents vs vote of the neighborhood (i.e. replacement probability) => recursive decision ?
	
	# If at least one dependent sets require the slot => we keep
	# Statistical model for complete adaptation process => new decoder ?
	# P( adapted ) = 
	
	# CURRENT : expand through function terms (this includes verbs => anything rethorical)
	# Extractive behavior: attributes are modeled as slots => appearance based on simple features / hard contraints ? e.g. minimum modality support
	# Abstractive behavior: descriptive terms are validated by supported dependents => this can be controlled by the appearance model
	# Dynamic/flexible template as opposed to a static template: non-extractive terms present in the neighborhood are included either based on support or based on the support of their descendents. We can add a component that is based on a prediction based on direct features of the target object itself, but this is not the only source of information we can consider.
	# TODO : only include function node if involved in dependency with supported/appearing token
	
	# Note : SLOT_ means we were not able to find any replacement candidate
	# Note : appearance decision for each token and expand dependency tree as much as possible

	if ( $this->_segments->[ $i ]->is_pinned ) {
	    # nothing
	}
	elsif ( $segment_option->is_punctuation ) {
	    # nothing
	}
	# CURRENT : drop slot if no filler can be found => how do we define filler confidence ? it would be sufficient to just say we want a filler that is better than the current filler
	elsif ( ! $this->segment_appearance( $i , $segment_option , $segment_option_probability ) ) {
	    
	    $appearance = 0;
	    
	    my $reinstate = 0;
	    
	    # CURRENT : problem - dependencies are derived from string prior to slot merging => what can we do here ?
	    my @successors = $this->component_dependencies->successors( $original_node_id );
	    my @predecessors = $this->component_dependencies->predecessors( $original_node_id );
	    
	    # TODO : for abstractive slots, use nagivational anchortext as replacement candidates ?
	    
	    if ( $reinstate ) {
		
		# reinstate original token
		$segment_option = $this->_segments->[ $i ]->original_as_token;
		
		# TODO : the token probability could depend on whether we are in compression mode or not
		# Note : the SLOT_ markers have the probability of the original filler
		##$segment_option_probability = 1;
		
	    }
	    
	}
    
	push @token_sequence , [ $segment_option , $segment_option_probability , $appearance ];
	
    }

=pod    
    my @connectors = map {
	my $connector_index = $this->component_index( $_ - 1 );
	[ $connector_index , $this->original_sequence->object_sequence->[ $connector_index ]->id ];
    } grep {
	my $token = $token_sequence[ $_ ]->[ 0 ];
	if ( ! ref( $token ) || $token->is_punctuation || $token->is_special ) {
	    0;
	}
	else {
	    ! $this->component_dependencies->has_vertex( $this->component_index( $_ - 1 ) );
	}
	# CURRENT : token sequence can be made up of post-processed tokens => i.e. does not match the original sequence
    } ( 0 .. $#token_sequence );
=cut

    return [ \@token_sequence , \%id2remove ];
    
}

has '_connector_to_sorted_dependencies' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_connector_to_sorted_dependencies_builder' );
sub _connector_to_sorted_dependencies_builder {

    my $this = shift;

    my %connector_to_sorted_dependencies;

    map {
	
	my @unsorted = @{ $_ };
	my $dependency_type = $this->component_dependencies->get_edge_attribute( @unsorted , 'dependency-type' );
	my @sorted = sort { $a <=> $b } @unsorted;
	
	if ( $dependency_type =~ m/^(\w+)_(\w+)$/si ) {
	    my $connector = $2;
	    if ( ! defined( $connector_to_sorted_dependencies{ $connector } ) ) {
		$connector_to_sorted_dependencies{ $connector } = [];
	    }
	    push @{ $connector_to_sorted_dependencies{ $connector } } , [ $connector , @sorted ];
	}
	
    } $this->component_dependencies->edges;

    return \%connector_to_sorted_dependencies;

}

# TODO : need better encapsulation
sub component_index {
    my $this = shift;
    my $local_index = shift;
    my $direction = shift || 1;
    return ( $direction * ( $this->component_id ? $this->original_sequence->components->[ $this->component_id ]->[ 2 ] : 0 ) ) + $local_index;
}

# TODO : MRF/CRF to enforce consistent replacement globally ?

sub finalize_viterbi {

    # CURRENT : make sur bigram transitions are properly contraining decoding
    # NEXT    : see how involved it would be to move to decoding using tri-grams

    my $this = shift;

    my @segments = @{ $this->_segments->[ 0 ] };

    # build decoding graph
    my $graph = new Graph::Directed;

    # having all options at every location, generate all possible transitions with their unnormalized probabilities
    my %transitions_sets;
    for ( my $i = 1 ; $i <= $#segments ; $i++ ) {

	# generate all possible transitions between ($i - 1) and $i

	my $current_segment_options = $segments[ $i ];
	my $previous_segment_options_index = $this->_find_previous_segment_index( \@segments , $i - 1 );
	my $previous_segment_options = $segments[ $previous_segment_options_index ];
 
	my $has_nonzero_transition = 0;
	foreach my $current_segment_option (@{ $current_segment_options }) {
		    
	    # CURRENT : if there is only one option, the transition probability must be one
	    my $to_token = $current_segment_option->[ 0 ];
	    my $emission_probability = $current_segment_option->[ 1 ];	    

	    foreach my $previous_segment_option (@{ $previous_segment_options }) {

		# Note : the emission probability is the emission probability of the destination token
		my $from_token = $previous_segment_option->[ 0 ];

		# Note : given by language model
		if ( $from_token eq $this->symbol_removal ) {
		    
		    # Note : find previous segment that has at least one non removal option
		    my $alternate_previous_segment_index = $this->_find_previous_segment_index( \@segments ,
												$previous_segment_options_index - 1 );
		    my $alternate_previous_segment_options = $segments[ $alternate_previous_segment_index ];
		    foreach my $alternate_previous_segment_option (@{ $alternate_previous_segment_options }) {

			my $_from_token = $alternate_previous_segment_option->[ 0 ];

			# Note : the perfect solution is to recurse again to find preceding anchor tokens
			if ( $_from_token eq $this->symbol_removal ) {
			    next;
			}

			$this->_add_transition( \%transitions_sets , $_from_token , $to_token , $emission_probability );

		    }

		}
		elsif( $to_token eq $this->symbol_removal ) {

		    my $alternate_next_segment_index = $this->_find_previous_segment_index( \@segments , $i + 1 , forward => 1 );

		    my $alternate_next_segment_options = $segments[ $alternate_next_segment_index ];
		    foreach my $alternate_next_segment_option (@{ $alternate_next_segment_options }) {
			
			my $_to_token = $alternate_next_segment_option->[ 0 ];

			# Note : the perfect solution is to recurse again to find following anchor tokens
			if ( $_to_token eq $this->symbol_removal ) {
			    next;
			}

			# Note : the emission probability will now be that of the replacement target token
			my $_emission_probability = $alternate_next_segment_option->[ 1 ];

			$this->_add_transition( \%transitions_sets , $from_token , $_to_token , $_emission_probability );

		    }

		}
		else {

		    $this->_add_transition( \%transitions_sets , $from_token , $to_token , $emission_probability );

		}
		
	    }

	}

    }

    # normalize transitions and create edges
    foreach my $from_token (keys( %transitions_sets )) {

	my $transitions_set = $transitions_sets{ $from_token };
	my @to_tokens = keys( %{ $transitions_set } );

	# Note : normalization from a given node => must sum to 1
	my $transitions_set_normalizer = 0;

	my @transitions = map {
	    
	    my $to_token = $_;
	    my $transition_emission_probability = $transitions_set->{ $to_token };
	    
	    # Note: the probability of transition is based on the summary language model
	    my $transition_probability_unnormalized = $transition_emission_probability *
		( $this->do_replacement_only || $this->_transition_probability( $from_token , $to_token ) );	    
	    $transitions_set_normalizer += $transition_probability_unnormalized;

	    [ $from_token , $to_token , $transition_probability_unnormalized ];
	    
	} @to_tokens;

	my @adjusted_transitions;
	if ( $transitions_set_normalizer ) {
	    # filter out zero transitions;
	    @adjusted_transitions = grep { $_->[ 2 ] } @transitions;
	}
	else {
	    # give uniform probability to all transitions (is this the right thing to do ?)
	    $this->logger->warn( "Outgoing transitions sum to 0 - uniformizing ..." );
	    @adjusted_transitions = map { $_->[ 2 ] = 1; $_ } @transitions;
	    $transitions_set_normalizer = scalar( @adjusted_transitions );
	}

	my $single_transition = ( scalar(@adjusted_transitions) == 1 ) ? 1 : 0;

	foreach my $transition_entry (@adjusted_transitions) {
	    
	    my $unnormalized_prob = $transition_entry->[ 2 ];
	    my $log_prob = $single_transition ? 0 : -log( $unnormalized_prob / ( $transitions_set_normalizer ) );
	    
	    $graph->set_edge_weight( $this->_get_node_id( $transition_entry->[ 0 ] ) ,
				     $this->_get_node_id( $transition_entry->[ 1 ] ) , $log_prob );

	}

    }

    # output graph if requested
    if ( $this->do_write_graph ) {

	my $graph_viewable = new Graph::Directed;
	my %index;
	map {
	    my $edge = $_;
	    $graph_viewable->set_edge_weight(
		map{
		    my $node = $this->_get_node( $_ );
		    if ( ! defined( $index{ $node } ) ) {
			$index{ $node } = scalar( keys( %index ) );
		    }
		    my $node_index = $index{ $node };
		    ref( $node ) ? join('-',$node->surface,$node_index) : $node
		} @{ $edge } ,
		$graph->get_edge_weight( @{ $edge } ) );
	} $graph->edges;

	my $writer = new Graph::Writer::Dot;

	$writer->write_graph( $graph_viewable , '/home/ypetinot/graph.dot' );
    }

    # compute shortest path
    my @shortest_path = $graph->SP_Dijkstra( $this->_get_node_id( $this->start_node ) , $this->_get_node_id( $this->end_node ) );

    my $best_log_prob = 0;
    for ( my $i = 0 ; $i < $#shortest_path ; $i++ ) {
	my $edge_weight = $graph->get_edge_weight( $shortest_path[ $i ] , $shortest_path[ $i + 1 ] );
	$best_log_prob += $edge_weight;
    }

    my $summary_probability = exp( - $best_log_prob );

    return ( \@shortest_path , $summary_probability );

}

has 'template_structure' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_template_structure_builder' );
sub _template_structure_builder {
    my $this = shift;
    return $this->seek_and_adapt_wrapper;
}

my $DECODING_MODE_HUNGARIAN='hungarian';
my $DECODING_MODE_VITERBI='viterbi';
method finalize ( :$decoding_mode , :$compressed = 0 , :$neighbors = [] ) {

    # make sure the sequence is ready to be finalized
    $self->template_structure;

    my ( $optimal_sequence , $optimal_sequence_score ) = ( $decoding_mode eq $DECODING_MODE_HUNGARIAN ) ?
	$self->finalize_hungarian( compressed => $compressed , neighbors => $neighbors ) :
	$self->finalize_viterbi( compressed => $compressed , neighbors => $neighbors );
    my @path = @{ $optimal_sequence };

    # remove start/end nodes
    shift @path;
    pop @path;

    # TODO : the rest of the method can probably be shared between all decoders
    my @finalized_token_sequence = grep { ref( $_ ); } map { ref( $_ ) ? $_ : $self->_get_node( $_ ) } @path;

    # TODO : is this step generic enough to be left here ?
    # CURRENT : remove broken dependencies
    # => i need to have the original node index => dependency pointers ?

    my $summary_probability = $optimal_sequence_score;
    affirm { $summary_probability <= 1 } "Summary probability cannot be greater than 1" if DEBUG;

    # CURRENT/TODO : add length probability factor => estimated on neighborhood => would naturally assign 0 probability to empty string
    if ( ! scalar( @finalized_token_sequence ) ) {
	$self->logger->debug( "Adapted sequence is empty - forcing probability to 0 - to be fixed" );
	$summary_probability = 0;
    }

    return ( \@finalized_token_sequence , $summary_probability );

}

sub _add_transition {

    my $this = shift;
    my $transitions_sets = shift;
    my $from_token = shift;
    my $to_token = shift;
    my $emission_probability = shift;

    my $from_token_id = $this->_get_node_id( $from_token );
    my $to_token_id = $this->_get_node_id( $to_token );

    if ( defined( $transitions_sets->{ $from_token_id }{ $to_token_id } ) ) {
	# Note : this may happen since i'm connecting nodes both forwards and backwards
	# Nothing
    }
    else {
	# TODO : shouldn't the emission probability simply be attached to to_token ?
	$transitions_sets->{ $from_token_id }{ $to_token_id } = $emission_probability;
    }

}

method _find_previous_segment_index ( $segments , $from_index , :$forward = 0 ) {

    my $min_index = $forward ? $from_index : 0;
    my $max_index = $forward ? ( scalar( @{ $segments } ) - 1 ) : $from_index;
    my $step      = $forward ? 1 : -1; 
    
    # find closest segment that has at least one non-removal option
    my $found = 0;
    my $current_index = $from_index;
    my $current_segment_options = undef;
    while ( !$found && ( $current_index >= $min_index ) && ( $current_index <= $max_index ) ) {
	
	$current_segment_options = $segments->[ $current_index ];
	
	# check acceptability of segment
	if ( ( scalar( @{ $current_segment_options } ) > 1 ) || 
	     ( $current_segment_options->[ 0 ] ne $self->symbol_removal ) ) {
	    $found = 1;
	    last;
	}

	$current_index += $step;
	
    }

    affirm { $found } "Linear structure must be guaranteed" if DEBUG;
    affirm { $current_index >= $min_index && $current_index <= $max_index } "Cannot reach an external index" if DEBUG;

    return $current_index;

}

sub _conditional_appearance_probability {

    my $this = shift;
    my $candidate = shift;

    # 1 - check support
    my $candidate_token = new Web::Summarizer::Token( surface => $candidate );
    if ( $this->target->supports( $candidate_token ) ) {
	return 1;
    }

    # CURRENT : other options to measure appearance probability ?
    # => instance types ?
    # => nearest neighbors => 
    $this->logger->debug( "Implement conditional appearance probability when there is no direct target support ..." );

    return 0;

}

sub segment_count {
    my $this = shift;
    return scalar( @{ $this->_segments } );
}

sub get_segment {
    my $this = shift;
    my $index = shift;
    return $this->_segments->[ $index ];
}

# TODO : add indexing
sub get_segment_at_token_index {
    my $this = shift;
    my $token_index = shift;
    foreach my $segment ( @{ $this->_segments } ) {
	if ( ( $token_index >= $segment->from ) && ( $token_index <= $segment->to ) ) {
	    return $segment;
	}
    }
    affirm { 0 } 'Should never reach this point' if DEBUG;
}

my $APPEARANCE_FEATURE_KEY_STATUS_FUNCTION = 'status::function';
my $APPEARANCE_FEATURE_KEY_TOKEN_IS_TYPED = 'token_is_typed';
my $APPEARANCE_FEATURE_KEY_TOKEN_MODALITY_FREQUENCY = 'token_modality_frequency';
my $APPEARANCE_FEATURE_KEY_TOKEN_IS_SUPPORTED = 'token_is_supported';
my $APPEARANCE_FEATURE_KEY_ORIGINAL_TOKEN_IS_SUPPORTED = 'original_token_is_supported';
my $APPEARANCE_FEATURE_KEY_SEGMENT_IS_UNFILLED = 'segment_is_unfilled';
my $APPEARANCE_FEATURE_KEY_DEPENDENTS_AT_LEAST_ONE_SUPPORTED = 'dependents_at_least_one_supported';
my $APPEARANCE_FEATURE_KEY_SEGMENT_IS_ABSTRACTIVE = 'segment_is_abstractive';
my $APPEARANCE_FEATURE_KEY_NEIGHBORHOOD_PRIOR = 'neighborhood_prior';
my $APPEARANCE_FEATURE_KEY_IS_SLOT_LOCATION = 'is_slot_location';
my $APPEARANCE_FEATURE_KEY_TYPE_COMPATIBILITY = 'type_compatibility';
my $APPEARANCE_FEATURE_KEY_NEXT_BEST_OPTION_MARGIN_2 = 'next_best_option_margin::2';
my $APPEARANCE_FEATURE_KEY_PROBABILITY = 'probability';
my $APPEARANCE_FEATURE_KEY_HAS_DEPENDENTS = 'has_dependents';
my $APPEARANCE_FEATURE_KEY_CANDIDATES_COUNT = 'candidates_count';
my $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES = 'candidates_probabilities' ;
my $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES_MEAN = 'candidates_probabilities_mean';
my $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES_STANDARD_DEVIATION = 'candidates_probabilities_standard_deviation';

# TODO : store as field (generate all segment features in one shot)
sub segment_features {

    my $this = shift;
    my $segment_index = shift;
    my $segment_option = shift;
    my $segment_option_probability = shift;

    my $segment = $this->get_segment( $segment_index );

    # ************************************************************************************************************************
    # appearance features

    my %appearance_features;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_PROBABILITY } = $segment_option_probability;

    my $segment_status_function = $segment->is_function ? 1 : 0;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_STATUS_FUNCTION } = $segment_status_function;

    my $segment_option_original = $this->_segments->[ $segment_index ]->original_as_token;
    my $token_is_typed = $segment_option_original->abstract_type ? 1 : 0;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_TYPED } = $token_is_typed;

    #my $token_modality_frequency = $this->target->supports( $segment_option );
    my $token_modality_frequency = $this->target->supports( $segment_option );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_TOKEN_MODALITY_FREQUENCY } = $token_modality_frequency;
    
    my $token_is_supported = $this->target->supports( $segment_option );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_SUPPORTED } = $token_is_supported;

    my $original_token_is_supported = $this->target->supports( $segment_option_original , regex_match => 1 );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_ORIGINAL_TOKEN_IS_SUPPORTED } = $original_token_is_supported;

    my @sorted_probabilities = sort { $b <=> $a } map { $_->[ 1 ] } @{ $this->_segments->[ $segment_index ]->options };
    my $best_option_probability = $sorted_probabilities[ 0 ];
    my $next_best_option_probability = ( scalar( @sorted_probabilities ) > 1 ) ? $sorted_probabilities[ 1 ] : 0;
    my $next_best_option_margin_2 = ( $best_option_probability > 2 * $next_best_option_probability ) ? 1 : 0;

    my $segment_is_unfilled = ( $segment_option->surface =~ m/SLOT_(\d+)/ ) ? 1 : 0;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_SEGMENT_IS_UNFILLED } = $segment_is_unfilled;
    
    # determine if successors are all function/supported terms
    # CURRENT : if successors are function (supported ?) tokens => keep original
    # Note : dependents should not include dependents that are connected by conjunctions/appositions
    my @segment_dependents = @{ $segment->get_segment_successors };
    $appearance_features{ $APPEARANCE_FEATURE_KEY_HAS_DEPENDENTS } = scalar( @segment_dependents ) ? 1 : 0;

    my $dependents_all_supported = ( scalar( grep { $_->is_function } @segment_dependents ) == scalar( @segment_dependents ) ) ? 1 : 0;
    my $dependents_at_least_one_supported = scalar( grep {
	my $dependent_token = $_->options->[ 0 ]->[ 0 ];
	! $dependent_token->is_punctuation && $this->target->supports( $dependent_token , regex_match => 1 );
						    } @segment_dependents ) ? 1 : 0;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_DEPENDENTS_AT_LEAST_ONE_SUPPORTED } = $dependents_at_least_one_supported;

    my $segment_is_abstractive = $segment->is_abstractive;
    $appearance_features{ $APPEARANCE_FEATURE_KEY_SEGMENT_IS_ABSTRACTIVE } = $segment_is_abstractive;

    my $neighborhood_prior = $this->neighborhood->prior( $segment_option->id , ignore => $this->original_sequence->object );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_NEIGHBORHOOD_PRIOR } = $neighborhood_prior;

    my $type_compatibility = $this->type_compatibility( $segment_option_original , $segment_option );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_TYPE_COMPATIBILITY } = $type_compatibility;

    # Note : to inherit from slot features I would need to make every location a slot
    if ( ref( $segment_option ) eq 'Web::Summarizer::FeaturizedToken' ) {
	
	$appearance_features{ $APPEARANCE_FEATURE_KEY_IS_SLOT_LOCATION } = 1;

	# Note : these features are (currently) not used in manual formulations => no feature keys for these
	my $slot_filler_features = $segment_option->features;
	map {
	    $appearance_features{ join( '::' , 'slot' , $_ ) } = $slot_filler_features->{ $_ };
	} keys( %{ $slot_filler_features } );
	
    }

    # Note : finally generate all feature combinations
    $this->_generate_feature_combinations( \%appearance_features );

    $appearance_features{ $APPEARANCE_FEATURE_KEY_CANDIDATES_COUNT } = scalar( @sorted_probabilities );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES } = \@sorted_probabilities ;
    my $_candidates_probabilities_mean = mean( @sorted_probabilities );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES_MEAN } = $_candidates_probabilities_mean->query;
    my $_candidates_probabilities_standard_deviation = stddev( @sorted_probabilities );
    $appearance_features{ $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES_STANDARD_DEVIATION } = $_candidates_probabilities_standard_deviation->query;

    # TODO : implement compression using graph cuts
    # CURRENT : slots correspond to attributes, this is where we have variability

    # ************************************************************************************************************************

    # ************************************************************************************************************************
    # appearance ground truth estimation

    # CURRENT : energy/cost function that is based on a logit formulation + per-instance cost
    # CURRENT : how to fit a logistic regression using EM ? => loss function is clear / just need to figure out how to compute assignments ? note that instances are not independent => maybe learning to cut trees instead ?
    
    if ( $this->output_learning_data ) {

	# CURRENT : formulation does not make sense => there should be a way to take into account the fact that dependents have a status ? ILP or MRF ?

	# CURRENT : string similarity (F-measure ?) evolution if we remove this token
	# => representation if we remove token ?
	# 1 - replicate dependencies
	my $dependencies_copy = $this->component_dependencies->deep_copy;
	
	# 2 - simulate segment removal
	$dependencies_copy->delete_vertex( @{ $segment->token_ids } );
	
	# 3 - linearize graph
	# TODO : progressively reimplement Sentence / AdaptableSequence / ScanningAdaptableSequence / etc. using linked lists ...
	my $tentative_output_kept = $this->linearize_dependency_graph( $this->component_dependencies );
	my $tentative_output_removed = $this->linearize_dependency_graph( $dependencies_copy );
	
	# 4 - compare to ground truth use P/R metric
	my $ground_truth_summary = $this->target->summary_modality->content;
	# TODO : switch to f1 ?
	my $similarity_with = Similarity::_compute_cosine_similarity( $ground_truth_summary , $tentative_output_kept );
	my $similarity_without = Similarity::_compute_cosine_similarity( $ground_truth_summary , $tentative_output_removed );

	my $ground_truth = ( $similarity_with > $similarity_without ) ? 1 : 0;

	print STDERR join( "\t" , "__INSTANCE_APPEARANCE__" , $this->target->url , $segment_option->surface , $ground_truth , encode_json( \%appearance_features ) ) . "\n";

    }

    # ************************************************************************************************************************

    return \%appearance_features;

}

# => maximize number of dependencies supported by target * probability
# => maximize number of dependencies supported by neighborhood * probability
# TODO : what is the difference between a loss function and an energy function ?
# => ground truth ? problem is whether we consider the consequences through dependencies ?
# => structured perceptron => we need to represent
# => RNN training for trees ? come up with featurization for each node 
# => cost of inclusion => e.g. joint probability of self and dependents - should be how many positive inclusion vs how many negative inclusions this leads to ?
# => look at full list ?
sub segment_appearance {
    
    my $this = shift;
    
    my $segment_index = shift;
    my $segment_option = shift;
    my $segment_option_probability = shift;

    my $segment_features = $this->segment_features( $segment_index , $segment_option , $segment_option_probability );

    return $this->appearance_function( $segment_features , $segment_option );

}

# ************************************************************************************************************************
# appearance function(s)

# => use slot centrality to score ?

sub appearance_function {

    my $this = shift;
    my $appearance_features = shift;
    
    # by default the slot should not appear
    my $appearance = 0;

    # TODO : add rule so that supported fillers are always preserved ?

    if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_STATUS_FUNCTION } || $appearance_features->{ $APPEARANCE_FEATURE_KEY_PROBABILITY } >= 0.5 ) {
	# TODO : we still need to drop function words that are no longer connected with any content token
	$appearance = 1;
    }
    elsif ( ! $appearance_features->{ $APPEARANCE_FEATURE_KEY_SEGMENT_IS_UNFILLED } ) {

	if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_CANDIDATES_COUNT } == 1 ) {
	    
	    # if only one option - must be supported
	    if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_SUPPORTED } ) {
		$appearance = 1;
	    }
	    #if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_MODALITY_FREQUENCY } > 1 ) {
	    #   $appearance = 1;
	    #}
	    
	}
	else {

	    # => node confidence ??? => only one option (supported) or twice as likely as next best option (i.e. margin) => 1 standard deviation to next best option ?

	    my $candidate_probabilities = $appearance_features->{ $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES };
	    if ( $candidate_probabilities->[ 0 ] - $candidate_probabilities->[ 1 ] > 2 * $appearance_features->{ $APPEARANCE_FEATURE_KEY_CANDIDATES_PROBABILITIES_STANDARD_DEVIATION } ) {
		$appearance = 1;
	    }

	}

    }

    return $appearance;

}

sub appearance_function_1 {

    my $this = shift;
    my $appearance_features = shift;
    
    # by default the slot should not appear
    my $appearance = 0;

    if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_STATUS_FUNCTION } ) {
	# TODO : we still need to drop function words that are no longer connected with any content token
	$appearance = 1;
    }
    elsif ( ! $appearance_features->{ $APPEARANCE_FEATURE_KEY_SEGMENT_IS_UNFILLED } ) {

	# TODO : extend to associated entity ids
		
	# Note : if the current filler is supported always let the best option appear
	if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_ORIGINAL_TOKEN_IS_SUPPORTED } ) {
	    $appearance = 1;
	}
	# Note : we do not judge the quality of the replacement, just its confidence
	# => technically this could be merged with the slot replacement scoring function, but it seems easier to separate the two
	elsif ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_TYPED } &&
		$appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_MODALITY_FREQUENCY } > 1 ) {
	    # CURRENT : ensure that there is minimal type compatibility
	    # TODO : Bayesian model >> expect types to be compatible with probability at least 0.5
	    if ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_TYPE_COMPATIBILITY } > 0.5 ) {
		$appearance = 1;
	    }
	}
	# best option must be twice as likely as the next best option => margin
	elsif ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_NEXT_BEST_OPTION_MARGIN_2 } ) {
	    $appearance = 1;
	}
# Note : we always need 2 options ?
# CURRENT : the absolute probability of the token is not a good indicator since the more candidates are present, the more diluted it is => use differential with other candidates instead 
	# TODO : we should probably enforce the frequency threshold at candidate collection time
	elsif ( ! $appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_TYPED } &&
		$appearance_features->{ $APPEARANCE_FEATURE_KEY_PROBABILITY } > 0.5 &&
		$appearance_features->{ $APPEARANCE_FEATURE_KEY_TOKEN_IS_SUPPORTED } > 1 ) {
	    $appearance = 1;
	}
	elsif ( $appearance_features->{ $APPEARANCE_FEATURE_KEY_DEPENDENTS_AT_LEAST_ONE_SUPPORTED } &&
		$appearance_features->{ $APPEARANCE_FEATURE_KEY_SEGMENT_IS_ABSTRACTIVE } ) {
	    #$reinstate = 1;
	    $appearance = 1;
	}

    }

    return $appearance;

}

# ************************************************************************************************************************

sub linearize_dependency_graph_to_segments {

    my $this = shift;
    my $dependency_graph = shift;

    my @token_ids = $dependency_graph->all_successors( -1 );
    my @segment_ids = uniq sort { $a <=> $b } map { $this->_token_2_segment->{ $_ } } @token_ids;

    return \@segment_ids;

}

sub linearize_dependency_graph {

    my $this = shift;
    my $dependency_graph = shift;

    my @segment_ids = @{ $this->linearize_dependency_graph_to_segments( $dependency_graph ) };

    my @segment_adapted = map {
	my $segment = $this->get_segment( $_ );
	# Note : assumes the segment options are sorted by decreasing probability
	$segment->options->[ 0 ]->[ 0 ]->surface;
    } @segment_ids;    

    my $linearized_dependency_graph = join( ' ' , @segment_adapted );

    return $linearized_dependency_graph;
					    
}

sub type_compatibility {
    
    my $this = shift;
    my $token_1 = shift;
    my $token_2 = shift;

    my $token_1_type_signature = $this->type_signature( $token_1->surface );
    my $token_2_type_signature = $this->type_signature( $token_2->surface );

    return Vector::cosine( $token_1_type_signature , $token_2_type_signature );

}

# TODO : generate all combinations involving 3 features => n features
# TODO : technically the next step would be to look into deep learning to better explore the feature space
sub _generate_feature_combinations {

    my $this = shift;
    my $features = shift;

    my @feature_keys = keys( %{ $features } );
    my $feature_count = scalar( @feature_keys );
    for ( my $i = 0 ; $i < $feature_count ; $i++ ) {
	my $feature_key_i = $feature_keys[ $i ];
	my $feature_value_i = $features->{ $feature_key_i };
	for ( my $j = $i+1 ; $j < $feature_count ; $j++ ) {
	    my $feature_key_j = $feature_keys[ $j ];
	    my $feature_value_j = $features->{ $feature_key_j };
	    my $combination_key = join( '::' , 'combination' , $feature_key_i , $feature_key_j );
	    my $combination_value = $feature_value_i * $feature_value_j;
	    if ( $combination_value ) {
		$features->{ $combination_key } = $combination_value;
	    }
	}
    }

}

__PACKAGE__->meta->make_immutable;

1;
