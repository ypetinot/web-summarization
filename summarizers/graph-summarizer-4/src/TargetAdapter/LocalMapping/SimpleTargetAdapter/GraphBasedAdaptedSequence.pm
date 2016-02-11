package TargetAdapter::LocalMapping::SimpleTargetAdapter::GraphBasedAdaptedSequence;

use strict;
use warnings;

use Carp::Assert;
use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence' );

our $SEGMENT_DEPENDENCIES_EDGE_ATTRIBUTE_CONNECTORS = 'connectors';

# dependencies between segments
has 'segment_dependencies' => ( is => 'ro' , isa => 'Graph::Directed' , init_arg => undef , lazy => 1 , builder => '_segment_dependencies_builder' );
sub _segment_dependencies_builder {

    my $this = shift;

    my $segment_dependencies_graph = new Graph::Directed;

    my @segments = @{ $this->_segments };
    my %edge2seen;
    for ( my $segment_id = 0 ; $segment_id <= $#segments ; $segment_id++ ) {

	my $segment = $segments[ $segment_id ];

	my @segment_successors_ids = @{ $segment->get_segment_successors_ids( all_successors => 0 ) };
	foreach my $segment_successor_id (@segment_successors_ids) {

	    affirm { $segment_successor_id != $segment_id } 'Self-loops may not occur' if DEBUG;
	    my $segment_successor = $segments[ $segment_successor_id ];

	    # connectors ? => final scan over original sequence => add as edge property including index in original sequence
	    my @connectors;
	    for ( my $i = $segment->to + 1; $i < $segment_successor->from - 1; $i++ ) {
		if ( $this->original_sequence->is_connector( $i ) ) {
		    my $token = $this->original_sequence->object_sequence->[ $i ];
		    push @connectors , [ $i , $token->surface ];
		}
	    }

	    my $edge_key = join( ":::" , $segment_id , $segment_successor_id );
	    affirm { ! $edge2seen{ $edge_key }++ } 'segment dependency edges can only be seen once' if DEBUG;

	    # add dependency edge + connector property
	    # TODO : a potential problem is that this may still leads to the creation of loops in the graph
	    # Twice-monthly student newspaper of Saint Peter 's College in Jersey City .
	    # 0-5,3-1,3-2,3-5,5-3,5-7
	    $segment_dependencies_graph->set_edge_attribute( $segment_id , $segment_successor_id ,
							     $SEGMENT_DEPENDENCIES_EDGE_ATTRIBUTE_CONNECTORS , \@connectors );
	    
	}

    }

    return $segment_dependencies_graph;

}

# TODO - original compression graph - to be removed
=pod
    # ****************************************************************************************************************************
    # Compression graph
	
	my $current_token_probability = $current_token_entry->[ 1 ];
	my $current_token_appears = $current_token_entry->[ 2 ];

	my $current_token_index = $self->component_index( $i - 1 );
	my $current_token_is_connector = ref( $current_token ) && ( ! $current_token->is_punctuation ) && ( ! $self->component_dependencies->has_vertex( $current_token_index ) );
	
	if ( $compressed && ! $current_token_appears ) {
	    
	    # 1 - delete conjunction dependencies involving successors
	    my @conj_successors = grep { $compression_graph->get_edge_attribute( $current_token_index , $_ , 'dependency-type' ) =~ m/^conj_/si } $compression_graph->successors( $current_token_index );
	    foreach my $conj_successor (@conj_successors) {
		$compression_graph->delete_edge( $current_token_index , $conj_successor );
	    }
	    
	    # 2 - delete descendants and node itself
	    map {
		$compression_graph->delete_vertex( $_ )
	    } ( @conj_successors , $current_token_index );
	    
	}

  }

=cut

method finalize_hungarian( :$compressed = 0 , :$neighbors = [] ) {

    # CURRENT : separate _raw_finalization_hungarian from compression ?
    my ( $_token_sequence , $_id2remove ) = @{ $self->_raw_finalization_hungarian };

    # Note : this is the optimal sequence of tokens as determined by the hungarian algorithm
    my @token_sequence = @{ $_token_sequence };
    my %id2remove = %{ $_id2remove };

=pod
	# reanalyze dependencies
	# CURRENT : generate templated_sequence to get more generic dependencies (especially dependencies that put supported tokens at the root/top of the tree)
    
##        my @templated_sequence_tokens = map {  ( $self->is_in_slot( $_ ) && ! ( ref( $self->get_slot_at( $_ ) ) =~ m/Abstractive/ ) ) ? join( '_' , 'SLOT' , $self->get_status( $_ ) ) : $self->original_sequence->object_sequence->[ $_ ]->surface } @{ $self->_range_sequence };	
##        my @templated_sequence_tokens = map {  ( $self->get_status( $_ ) eq 'f' || $self->target->supports( $self->original_sequence->object_sequence->[ $_ ] , regex_match => 1 ) ) ? $self->original_sequence->object_sequence->[ $_ ]->surface : join( '_' , 'SLOT' , $self->get_status( $_ ) ) } @{ $self->_range_sequence };

        my @templated_sequence_tokens = map { ( ( $self->priors->[ $_ ] >= 0.5 ) || $self->original_sequence->object_sequence->[ $_ ]->is_punctuation ) ? $self->original_sequence->object_sequence->[ $_ ]->surface : join( '_' , 'SLOT' , $self->get_status( $_ ) ) } @{ $self->_range_sequence };
	my $template_dependencies = $self->original_sequence->_dependency_parsing_service->get_dependencies_from_tokens( \@templated_sequence_tokens );

        # CURRENT / TODO : use this set of dependencies to build a compression graph
=cut

=pod
    p Dumper( $self->original_sequence->_dependency_parsing_service->get_dependencies( "SLOT_0 student newspaper of SLOT_1's SLOT_2 in SLOT_3." ) )
=cut

    my $compression_graph = $self->segment_dependencies->deep_copy;
    my $score = 1;
    for ( my $i = 0 ; $i <= $#token_sequence ; $i++ ) {
	
	my $segment_entry = $token_sequence[ $i ];
	my $segment_option_probability = $segment_entry->[ 1 ];
	my $segment_appearance = $segment_entry->[ 2 ];

	if ( $compressed && !$segment_appearance ) {

	    # Note : delete parent segment if it is a function segment and does not have any other child
	    map {
		$compression_graph->delete_vertex( $_ );
	    }
	    grep {

		# 1 - check that this is a function segment
		my $is_function = $self->get_segment( $_ )->is_function;
		
		# 2 - check that this segment has no descendant at this point
		my $successors_count = scalar( $compression_graph->successors( $_ ) );

		$is_function && ( $successors_count == 1 );

	    } $compression_graph->predecessors( $i );

	    # Note : no need to delete descendants if they end up being disconnected => we only generate by expanding from the root
	    $compression_graph->delete_vertex( $i );

	}
	else {

	    # TODO : should probability propagates to dependents ?
	    $score *= $segment_option_probability;

	}

    }

    my @token_sequence_final;
    my $current_token_index = -1;

    # Note : identify the main set of segments to be preserved
    my @segments_preserved = sort { $a <=> $b } $compression_graph->all_successors( 0 );

    # Note : identify connector segments that connect segments to be preserved    
    my %segment2preserve;
    map { $segment2preserve{ $_ }++ } @segments_preserved;
    my $previous_is_regular = 0 ;
    for ( my $segment_id = 0 ; $segment_id <= $#token_sequence ; $segment_id++ ) {

	my $segment = $self->get_segment( $segment_id );
	my $segment_tokens = $segment->tokens;
	my $segment_best_option = $token_sequence[ $segment_id ];
	my $segment_best_option_token = $segment_best_option->[ 0 ];
	my $segment_best_option_probability = $segment_best_option->[ 1 ];

	my $segment_token_count = scalar( @{ $segment_tokens } );
	my $segment_from = $segment->from;
	my $segment_to = $segment->to;

	my $keep = 0;

	if ( ! $compressed ) {
	    $keep = 1;
	}
	elsif ( $segment->is_pinned ) {
	    $keep = 1;
	}
	elsif ( ! $segment->is_pinned && ! $compression_graph->has_vertex( $segment_id ) ) {
		
	    if ( $segment_best_option_token->is_punctuation ) {
		# Note : we keep , any correction regarding punctuation is taken care of at a later stage
		$keep = 1;
	    }
	    elsif ( $self->original_sequence->is_connector( $segment_from ) ) {
		
		if ( $previous_is_regular ) {
		    
		    # Note : we are in a "connector segment"
		    # Note : we need to confirm that this connector links two preserved segments (wherever they are)
		    my $connector_data = $self->connector_data->{ $segment_from };
		    foreach my $connector_datum (@{ $connector_data }) {
			
			my $connector_from_token = $connector_datum->[ 1 ];
			my $connector_to_token = $connector_datum->[ 2 ];
			
			my ( $connector_from_segment_id , $connector_to_segment_id ) = map {
			    $self->get_segment_at_token_index( $_ )->id;
			} ( $connector_from_token , $connector_to_token );
			
			if ( $compression_graph->has_vertex( $connector_from_segment_id ) &&
			     $compression_graph->has_vertex( $connector_to_segment_id ) ) {
			    $keep = 1;
			    $previous_is_regular = 0;
			}
			
		    }
		    
		}
		
	    }

	}
	elsif( $segment2preserve{ $segment_id } ) {
	    
	    $keep = 1;
	    $previous_is_regular = 1;

	}
	
	if ( $keep ) {
            push @token_sequence_final , $segment_best_option_token;
	}

    }

# TODO : to be salvaged
=pod	
	# Scan original token position to identify which (original) tokens should be included in the output
	for ( my $i = $current_token_index ; $i <= $segment_from - 1 ; $i++ ) {

	    my $intermediate_token = $self->original_sequence->object_sequence->[ $i ];
	    my $intermediate_token_is_connector_keep = $connectors_keep{ $i };

	    if ( $intermediate_token->is_punctuation ) {
		# Note : the removal of extraneous punctuation tokens is handled downstream (finalize)
		push @token_sequence_final , $intermediate_token;
	    }
	    elsif ( $intermediate_token_is_connector_keep ) {
		# TODO : confirm this connector connects the last regular tokena and the current token
		push @token_sequence_final , $intermediate_token;
	    }

	$current_token_index = $segment_to + 1;

}
=cut

=pod
	
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

    return ( \@token_sequence_final , $score );

}

__PACKAGE__->meta->make_immutable;

1;
