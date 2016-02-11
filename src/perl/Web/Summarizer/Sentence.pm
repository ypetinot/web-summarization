package Web::Summarizer::Sentence;

# CURRENT : (2) serialization for individual sentences ? >> hashed

use strict;
use warnings;

use CoNLLChunkAdapter;
use Service::NLP::SentenceDependencyAnalyzer;
use Vector;

use Carp::Assert;
use List::MoreUtils qw/uniq/;
use Tree;

use Moose;
use MooseX::Aliases;
use namespace::autoclean;

# TODO : add non-object-conditioned super-class ?

extends 'Web::Summarizer::StringSequence';

# Note : should it be applied to a parent class ?
with Featurizable;

# TODO : maybe having this as a role doesn't make complete sense => try adding a "freebase_access" field to the role ?
with( 'Freebase' );

use overload
    '""'   => sub { my $a = shift; return $a->verbalize; };
# To be removed - now in Web::Summarizer::Sequence
#    '@{}'  => sub { my $a = shift; return $a->token_sequence; };

# parsing service
has '_parsing_service' => ( is => 'ro' , isa => 'Service::NLP::SentenceChunker' , init_arg => undef , lazy => 1 , builder => '_parsing_service_builder' );
sub _parsing_service_builder {
    my $this = shift;
    return Service::NLP::SentenceChunker->new;
}

# dependency parsing service
has '_dependency_parsing_service' => ( is => 'ro' , isa => 'Service::NLP::SentenceDependencyAnalyzer' , init_arg => undef , lazy => 1 , builder => '_dependency_parsing_service_builder' );
sub _dependency_parsing_service_builder {
    my $this = shift;
    return Service::NLP::SentenceDependencyAnalyzer->new;
}

# TODO : is this really an appropriate field name ?
has 'surface_string' => ( is => 'ro' , isa => 'Str' , lazy => 1 , builder => '_surface_string_builder' );
sub _surface_string_builder {
    my $this = shift;
    return join( " " , map { $_->surface } @{ $this->object_sequence } );
}

has 'grouped_string' => ( is => 'ro' , isa => 'Str' , lazy => 1 , builder => '_grouped_string_builder' );
sub _grouped_string_builder {
    my $this = shift;
    return join( " " , map { $_->surface_grouped } @{ $this->object_sequence } );
}

has '_string_analyzed_data' => (
#    traits => qw/Serializable/ # additional fields to specify location and builder to be provided by Trait ...
    is => 'ro' ,
    isa => 'ArrayRef' ,
    init_arg => undef ,
    lazy => 1 ,
    builder => '_string_analyzed_data_builder'
);
sub _string_analyzed_data_builder {
    my $this = shift;
    # TODO : run fuller analysis ? Is it possible in one pass ?
    $this->logger->debug( "Analyzing raw sentence associated with " . $this->object->url );
    return $this->_parsing_service->run( $this->raw_string );
}

# CURRENT: serialization
#          => MooseX::Storage handles serialization, but would have to explicitly request storage => logic would be to handle serialization of the full Sentence object => is this what we want ?
#          => do I want serialization at the field level ? => i.e. being to commit things dynamically on a per-field basis => yes

# self object support
has 'self_object_support' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_self_object_support_builder' );
sub _self_object_support_builder {
    my $this = shift;
    return $this->object_support( $this->object );
}

# dependencies
has 'dependencies' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_dependencies_builder' );
sub _dependencies_builder {

    my $this = shift;
    
    # CURRENT/TODO:
    # 1 - for verbalization => traverse dependency tree to determine which tokens should be dropped because they have a dependency on an unfillable slot
    # 2 - withing slot dependencies for fine-grained/recursive refilling

    # CURRENT : run Stanford parser (service ?) on this sentence ...
    $this->logger->debug( "Analyzing dependencies for raw sentence associated with " . $this->object->url );

    my @dependencies;
    foreach my $component_id ( 0 .. $this->component_count - 1 ) {
	my @component_tokens = map { $this->object_sequence->[ $_ ]->surface_grouped } ( $this->get_component_from( $component_id ) .. $this->get_component_to( $component_id ) );
	my $component_dependencies = $this->_dependency_parsing_service->get_dependencies_from_tokens( \@component_tokens );
	push @dependencies , $component_dependencies;
    }

    return \@dependencies;

}

our $DEPENDENCY_TYPE_KEY = 'dependency-type';
has 'dependencies_graphs' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_dependencies_graph_builder' );
sub _dependencies_graph_builder {
###sub apply_dependencies {
    
    my $this = shift;
    
    my $dependencies = $this->dependencies;

    my @dependencies_graphs;
    for ( my $component_id = 0 ; $component_id < scalar( @{ $dependencies } ) ; $component_id++ ) {
   
	my $dependency_set = $dependencies->[ $component_id ];
	my $dependencies_graph = new Graph::Directed;
	my %id2string;

	my @dependencies_raw = split /\n/ , $dependency_set->tree;
	map {

	    chomp;

	    my $dependency_object = new Service::NLP::Dependency( dependency_string => $_ );

	    # TODO : maintain per-component mapping instead 
            # Note : our local representation is 0-indexed => ROOT's id is -1

	    my $dependency_from = $dependency_object->from;
	    my $dependency_from_id_raw = $dependency_object->from_id;
	    #my $dependency_from_id = $dependency_from_id_raw ? $this->_token_index_mapping->{ $this->components->[ $component_id ]->[ 0 ] + $dependency_from_id_raw - 1 } : -1;
	    my $dependency_from_id = $dependency_from_id_raw ? $this->components->[ $component_id ]->[ 2 ] + $dependency_from_id_raw - 1 : -1;
	    $id2string{ $dependency_from_id } = $dependency_from;

	    my $dependency_to = $dependency_object->to;
	    my $dependency_to_id_raw = $dependency_object->to_id;
	    #my $dependency_to_id = $dependency_to_id_raw ? $this->_token_index_mapping->{ $this->components->[ $component_id ]->[ 0 ] + $dependency_to_id_raw - 1 } : -1;
	    my $dependency_to_id = $dependency_to_id_raw ? $this->components->[ $component_id ]->[ 2 ] + $dependency_to_id_raw - 1 : -1;
	    $id2string{ $dependency_to_id } = $dependency_to;

	    my $dependency_type = $dependency_object->type;

	    # create edge and set type attribute
	    $dependencies_graph->set_edge_attribute( $dependency_from_id , $dependency_to_id , $DEPENDENCY_TYPE_KEY , $dependency_type );

	    # TODO/Note : not easily doable right now, we need to make a full copy of the original token state when adding replacement candidates
	    #$this->object_sequence->[ $dependency_from_id ]->dependency( $dependency_to_id , $dependency_type )
	    
	} @dependencies_raw;

	push @dependencies_graphs , [ $dependencies_graph , \%id2string ];

    }

    return \@dependencies_graphs;

}

sub component_count {
    my $this = shift;
    my $component_count = scalar( @{ $this->_string_analyzed_data } );
    affirm { scalar( @{ $this->components } ) == $component_count } if DEBUG;
    return $component_count;
}

sub get_component_from {
    my $this = shift;
    my $component_index = shift;
    return $this->components->[ $component_index ]->[ 2 ];
}

sub get_component_to {
    my $this = shift;
    my $component_index = shift;
    # TODO : should I try to clean up this -1 ? Currently the first element is the position of the base while the second element is the offset for the following component.
    return $this->components->[ $component_index ]->[ 3 ] - 1;
}

sub get_component_id_for_index {
    my $this = shift;
    my $index = shift;
    for ( my $component_index = 0 ; $component_index < $this->component_count ; $component_index++ ) {
	# TODO : it might be necessary to have the last component entry be the index of the last token in the component
	if ( ( $this->components->[ $component_index ]->[ 2 ] <= $index ) && ( $this->components->[ $component_index ]->[ 3 ] > $index ) ) {
	    return $component_index;
	} 
    }
    affirm { 0 } 'Requested index must be within the sentence bounds' if DEBUG;
}

# TODO : ultimately add a builder ?
has 'components' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , default => sub { [] } );

# get character ngrams
sub get_character_ngrams {

    my $this = shift;
    my $order = shift;

    my %ngrams;

    return \%ngrams;

}

# get POS forest (ordered)
sub get_pos_forest {

    my $this = shift;
    my $token_builder = shift || \&_token_builder;

    my $token_builder_wrapper = sub {
	return $token_builder->( $this , @_ );
    };
    
    # convert analyzed string to tree structure
    # TODO : where should the mapping function be moved ?
    # CURRENT : would be nice to be able to use the Token objects as leaf nodes in our tree
    #           1 - node types + Token as values
    #           2 - activation for each node => top down / bottom up / forward-backward ?

    # TODO : check whether map_2_tree ever returns more than one tree => if not, we can directly have it return a single tree
    my @pos_forest = map { @{ CoNLLChunkAdapter->map_2_tree( $_->tree , $token_builder_wrapper ) } } @{ $this->_string_analyzed_data };

    return \@pos_forest;

}   

sub _token_builder {

    my $sentence = shift;
    my $is_leaf = shift;
    my $value = shift;
    my $_parent = shift;

    if ( ! $is_leaf ) {
	return undef;
    }

    # create token object
    my $token_object = new Web::Summarizer::Token(
	
	surface => $value ,
	pos => ( defined( $_parent ) ? $_parent->value : '' ) ,
	sequence => '',
	abstract_type => ''
	
	);
    
    return $token_object;

}

# TODO : should we move to a different (more public) method name ?
sub _tokenize {

    my $this = shift;

    my @token_sequences;

    my $pos_trees = $this->get_pos_forest;
    foreach my $pos_tree (@{ $pos_trees }) {
	my @token_sequence;
	# CURRENT : provide a call-back that decides whether to use all available sentences ?
	push @token_sequence , map { $_->value } grep { $_->is_leaf } $pos_tree->traverse( $pos_tree->POST_ORDER );
	push @token_sequences , \@token_sequence;
    }

    return \@token_sequences;

}

# TODO : store alongside segments ?
has 'named_entities' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_named_entities_builder' );
sub _named_entities_builder {
    my $this = shift;

    my $sentence_raw_string = $this->raw_string;
    my @named_entities_all;

    # 1 - named entities extracted from the sentence itself
    my $named_entities_sentence = $this->_parsing_service->get_named_entities( $sentence_raw_string );    
    push @named_entities_all , map { [ $_->{ 'entity' } , $_->{ 'tag' } , $_->{ 'startOffset' } , $_->{ 'endOffset' } , 0 ] } @{ $named_entities_sentence };

    # 2 - enrich *sequence* of named entities with entities extracted from the associated object
    # Note : this could be problematic as we may bring in pretty long entities (or what is detected as entities)
    my $named_entities_object = $this->object->named_entities;
    foreach my $named_entity_type ( keys( %{ $named_entities_object } ) ) {
	foreach my $named_entity ( keys( %{ $named_entities_object->{ $named_entity_type } } ) ) {
	    push @named_entities_all , [ $named_entity , $named_entity_type , -1 , -1 , 1 ];
	}
    }

    # 3 - sort by length ( should we only do this for the additional set of named entities ? )
    my @named_entities_sorted = sort { length( $b->[ 0 ] ) <=> length( $a->[ 0 ] ) } @named_entities_all;
    my @named_entity_2_positions;
    my @position_2_covered = map { 0 } ( 0 .. ( length( $sentence_raw_string ) - 1) );
    foreach my $named_entity_entry (@named_entities_sorted) {

	my $named_entity = $named_entity_entry->[ 0 ];
	my $named_entity_type = $named_entity_entry->[ 1 ];
	my $named_entity_from = $named_entity_entry->[ 2 ];
	my $named_entity_to = $named_entity_entry->[ 3 ];
	my $strict_matching = $named_entity_entry->[ 4 ];

	my $position = -1;

	my $regex = $strict_matching ? qr/(?:^|\W)(\Q$named_entity\E)(?:\W|$)/si : qr/(\Q$named_entity\E)/si ;
	while ( $sentence_raw_string =~ m/$regex/sig ) {

	    my $match_position_to = pos( $sentence_raw_string );
	    my $match_position_from = $match_position_to - length( $1 );
	    my @position_span = ( $match_position_from .. $match_position_to );

	    # check whether the current span is already covered
	    my $already_covered = grep { $position_2_covered[ $_ ] } @position_span;
	    if ( $already_covered ) {
		next;
	    }

	    push @named_entity_2_positions , [ $1 , $named_entity , $named_entity_type , $match_position_from , $match_position_to ];
	    map { $position_2_covered[ $_ ] = 3 } @position_span;

	}

    }

    # 2 - sort named entities by their point of appearance in the sentence
    my @named_entities_position_sorted = sort { $a->[ 3 ] <=> $b->[ 3 ] } @named_entity_2_positions;
    
    return \@named_entities_position_sorted;

}

# index mapping - used to map raw string indices to transformed string indices
has '_token_index_mapping' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# override: token transformer
sub token_transformer {

    my $this = shift;
    my $token_sequence = shift;
    my $component_id = shift;

    my $component_offset_original = $component_id ? $this->components->[ $component_id - 1 ]->[ 1 ] : 0;
    my $component_offset_transformed = $component_id ? $this->components->[ $component_id - 1 ]->[ 3 ] : 0;
    my $super_transformed = $this->SUPER::token_transformer( $token_sequence );

    # CURRENT : identify substrings of the sentence that appear in the associated object and check if these are entities
    # => for Freebase entity matching => get candidates from sentence and get candidates from object, only considering intersection ?
    # CURRENT : NER for object content ? => read stack-overflow post
    
    # TODO : how do we handle this case (post-processing to improve NER) ?
    # http://pauwwow.com
    # Extracting Named Entities: Twice-monthly student newspaper of Saint Peter's College in Jersey City.
    # => would break Saint Peter's College into individual tokens
    
    # 1 - NER on object => consider all entities that appear twice as single tokens => initial set
    
    # 3 - apply NER on summary with modified tokens
    # 4 - filter out NEs that have more than one incoming dependency

    # determine presence of named entites in summary (statistical NER)
    my @named_entities = map { [ $_->[ 0 ] , $_->[ 2 ] ] } @{ $this->named_entities };

    my @filtered_named_entities;
    foreach my $_named_entity (@named_entities) {

	my $named_entity = $_named_entity->[ 0 ];
	
	# TODO : this needs to be moved to Service::NLP::*
	# => replicate using "View from the Florida Keys . , photos ."
	if ( $named_entity =~ m/^(?:\p{PosixPunct}|\s)+$/ ) {
	    next;
	}

	my $entity_type = $this->map_string_to_entities( $named_entity );

	# check if each named entity appears in document
	if ( $entity_type || $this->object->supports( $named_entity , regex_match => 1 ) ) {
	    # ok
	    push @filtered_named_entities , $_named_entity;
	}
	else {
	    
	    # try to see if this names entity matches some of the associated object's entities
	    my $object_entities = $this->object->named_entities;
	    foreach my $object_entity_type ( (keys( %{ $object_entities })) ) {
		my $object_entities_type = $object_entities->{ $object_entity_type };
		my @object_entities_type_sorted = sort { length( $b ) <=> length( $a ) } keys( %{ $object_entities_type } );
		foreach my $object_entity (@object_entities_type_sorted) {
# Note : too aggressive ?
=pod
		    if ( $object_entities_type->{ $object_entity } < 2 ) {
			next;
		    }
=cut
		    if ( $named_entity =~ s/\Q$object_entity\E/ /si ) {
			# we have found a component entity
			push @filtered_named_entities , [ $object_entity , $object_entity_type ];
		    }
		}
	    }
	   
	}
	
    }
    
    my $n = scalar( @{ $super_transformed } );
    my $n_named_entities = scalar( @filtered_named_entities );
    my $current_named_entity = 0;
    my $found_named_entities_total = 0;
    my @transformed_token_sequence;
    for ( my $i = 0 ; $i < $n ; $i++ ) {

	my $found_named_entity = 0;

	if ( $current_named_entity < $n_named_entities ) {

	    my $named_entity = $filtered_named_entities[ $current_named_entity ];
	    my $named_entity_surface = $named_entity->[ 0 ];
	    my $named_entity_tag = $named_entity->[ 1 ];
	    
	    my $j = $i;
	    # TODO : is a permanent loop sufficient here ?
	    while ( $j < $n ) {
		
		# check if buffer matches named entity
		my $buffer_string = join( ' ' , map { $super_transformed->[ $_ ]->surface } uniq ( $i .. $j ) );
		
		if ( $named_entity_surface =~ m/^\Q$buffer_string\E/si ) {
		    if ( $named_entity_surface eq $buffer_string ) {
			# we have found a match
			$found_named_entity = 1;
			last;
		    }
		    else {
			$j++;
		    }
		}
		else {
		    last;
		}
		
	    }

	    if ( $found_named_entity ) {
		
		push @transformed_token_sequence , new Web::Summarizer::Token( surface => $named_entity_surface,
									       abstract_type => $named_entity_tag );
		
		# we can move on to the next entity
		$current_named_entity++;
		$found_named_entities_total++;

		# keep track of index mappings
		map { $this->_token_index_mapping->{ $component_offset_original + $_ } = $component_offset_transformed + $#transformed_token_sequence; } ( $i .. $j );

		$i = $j;
		next;
		
	    }

	}
	else {
	    # Should we be doing something here ?
	}

	# TODO : remove duplication with the push statement above ?
	push @transformed_token_sequence , $super_transformed->[ $i ];

	# keep track of index mappings
	$this->_token_index_mapping->{ $component_offset_original + $i } = $component_offset_transformed + $#transformed_token_sequence;
	
    }

    # Note : this is no longer true when working with components
    #affirm { $found_named_entities_total == $n_named_entities } "All named entities must be detectable" if DEBUG;

    # TODO : this probably belongs somewhere else but this is the best solution for now
    # update component information
    # [ original_from , original_to , transformed_from , transformed_to ]
    push @{ $this->components } , [ $component_offset_original , $component_offset_original + $n , $component_offset_transformed , $component_offset_transformed + $#transformed_token_sequence + 1 ];

    return \@transformed_token_sequence;

}

sub is_connector {
    
    my $this = shift;

    # Note : this is a raw index (not within a component)
    my $index = shift;
    
    # 1 - get component id for this index
    my $component_id = $this->get_component_id_for_index( $index );
    #my $component_index = $this->component_index( $component_id , $index , -1 );

    # 2 - check whether index appears in list of nodes
    my $token = $this->object_sequence->[ $index ];
    my $is_connector = ( ( ! $token->is_punctuation ) && ( ! $this->dependencies_graphs->[ $component_id ]->[ 0 ]->has_vertex( $index ) ) ) ? 1 : 0;
    
    return $is_connector;

}

sub get_connector_data {
    
    my $this = shift;
    my $connector_index = shift;

    my $token_index_from;
    my $token_index_to;
    my $type;

    return ( $token_index_from , $token_index_to , $type );

}

# TODO : remove code redundancy with the original component_index in AdaptedSequence
sub component_index {
    my $this = shift;
    my $component_id = shift;
    my $local_index = shift;
    my $direction = shift || 1;
    return ( $direction * ( $component_id ? $this->components->[ $component_id ]->[ 2 ] : 0 ) ) + $local_index;
}

__PACKAGE__->meta->make_immutable;

1;
