=pod
package TargetAdapter::TreeTargetAdapter::Node;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Tree' );

# CURRENT : provide custom Tree class that can seemlessly encapsulate its own adaptation (as opposed to building a separate tree)
#           => can be passed to CoNLLChunkAdapter => ok
#           => differentiation between inner and leaf nodes ?

# TODO : would it be convenient (more meaningful ?) to extend the Tree class ?

# target object
# TODO : could this be provided by the parent node ?
has 'target_object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# reference object
has 'reference_object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# value
has 'value' => ( is => 'ro' , isa => 'Str' , required => 1 );

# target supported
has 'target_supported' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_target_supported_builder' );
sub _target_supported_builder {
    my $this = shift;

    if ( $this->is_leaf ) {
	return $this->value->object_support( $this->target_object );
    }( ! scalar( grep { $_->target_supported} $this->children ) )
}

sub _supported_builder {
    my $this = shift;
    my $object = shift;
}

# reference supported

__PACKAGE__->meta->make_immutable;
=cut

package TargetAdapter::TreeTargetAdapter;

# Approach: bottom up approach (through a top-down recursion) that builds up transformed tree by checking, at each step the confidence in the underlying sub-tree
#           => again the top/down hierarchy can be imposed in various ways: syntax/semantics (dependencies)/specificity

use strict;
use warnings;

use Web::Summarizer::GeneratedSentence;

use Algorithm::Diff qw(
        LCS LCS_length LCSidx
        diff sdiff compact_diff
        traverse_sequences traverse_balanced );
use Carp::Assert;
use Memoize;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter' );
with( 'TargetAligner::WordDistance' );

=pod
has '_tree_adapter_token_builder' => ( is => 'ro' , isa => 'CodeRef' , init_arg => undef , lazy => 1 , builder => '_tree_adapter_token_builder_builder' );
sub _tree_adapter_token_builder_builder {

    my $this = shift;

    my $adapter_sub = sub {

	my $sentence = shift;
	my $is_leaf = shift;
	my $value  = shift;

	# TODO : can we do better ?
	if ( $is_leaf ) {
	    return Web::Summarizer::Sentence::_token_builder( $sentence , $is_leaf , $value );
	}

	return TargetAdapter::TreeTargetAdapter::Node->new( tag => $value );

    };
    
    return $adapter_sub;

}
=cut

# adapt by recursing on the POS tree of the reference sentence (summary)
sub _adapt {

    my $this = shift;
    # TODO : pass in a more integrated object (i.e. more integrated with the alignment data => Alignment object ?)
    my $original_sentence = shift;
    my $alignment = shift;

    # 1 - get pos tree
    my $original_sentence_parse_forest = $original_sentence->get_pos_forest(
	#$this->_tree_adapter_token_builder
	);

    # 2 - get support information for all leaf nodes => no longer needed ?
    # CURRENT : not good because support of the inner nodes is defined as a match (potential regular expression) defined by the sequence of its descendants
    #           ==> support for inner nodes == regular expression where reference-specific (non-target-supported) nodes are abstracted out => leads to extractive mapping, confidence is based on depth
    #           ==> support for leaf  nodes == object_support => if no support, backoff solutions ( regex generation >> if fails >> closest non-supported based on cost function ) with confidence levels
    #           ==> in case of multiple candidates, choose using cost function
    #
    #           ==> do i need to have in place substitution ? => does it make coding easier ?
    #           ==> 1 - code to generate regex for inner node => leads to extraction => how to replace child ? => index of place-hold is index of child
    #           ==> 2 - code to adopt leaf node => ok

    # 2 - recurse over tree
    # TODO : add confidence-based filtering
    my @adapted_forest = grep { defined( $_->[ 0 ] ) } map {
	my ( $adapted_tree , $adapted_tree_confidence ) = $this->_adapt_recursively( $original_sentence , $alignment , $_ );
	[ $adapted_tree , $adapted_tree_confidence ];
    } @{ $original_sentence_parse_forest };

    # 3 - linearize tree
    # TODO : can we create a Sentence object directly from a tree ?
    #        => single class where all representations of a string a treated as equivalent ?
    #        => core representation + bi-directional facet mappings ?
    #        => Sentence should simultaneously represent all aspects of a sentence (with a possibility of transforming the underlying sentence ?) => text-to-text toolkit ?
    my ( $linearized_forest , $linearized_forest_confidence ) = $this->_linearize_forest( \@adapted_forest );

    return Web::Summarizer::GeneratedSentence->new( raw_string => $linearized_forest , object => $this->target , source_id => __PACKAGE__ , score => $linearized_forest_confidence );

}

# CURRENT : assume each node in the tree can be scored based on confidence
#           => heuristic substitution + score for extractive
#           => appearance probability for abstractive (can be based on empirical distribution for now)

sub _linearize_forest {

    my $this = shift;
    my $forest = shift;

    my $linearized_forest_confidence = 0;
    my @linearized_trees = map {
	$linearized_forest_confidence = ( $linearized_forest_confidence || 1 ) * $_->[ 1 ];
	$this->_linearize_tree( $_->[ 0 ] );
    } @{ $forest };

    my $linearized_forest = join( " " , @linearized_trees );

    return ( $linearized_forest , $linearized_forest_confidence );

}

sub _linearize_tree {

    my $this = shift;
    my $tree = shift;

    # CURRENT : representation ? POS tree or dependency-like colapsed tree ? => the latter might be easier to handle for matching purposes
    my @leaf_nodes = $tree->traverse( $tree->POST_ORDER );

    return join( " " , map { $_->value->surface } grep { $_->is_leaf } @leaf_nodes );

}

sub _abstracted_out_regex {
    my $this = shift;
    my $token = shift;    
    return $token->is_numeric ? qr/^(\d+[^ ]*\d)$/ : qr/^(\w+(?: \w+)*)$/;
}

sub _adapt_recursively {

    # Note : in-place editing since hierarchical information is lost during regex-based adaptation => really ?

    my $this = shift;
    my $reference_sentence = shift;
    my $alignment = shift;
    my $node = shift;
    my $depth = shift || 0;

    my $reference_object = $reference_sentence->object;
    my $node_value = $node->value;

    # Note : we need to create new nodes to disconnect the adapted tree from the original
    my $adapted_node;
    my $adapted_node_confidence = 0;

    # leaf nodes : look for potential mapping
    # Note : what happens if we want to delete a node because, e.g. there is no confidence in its adaptation ?
    #        => return undef node => propagate upwards ? => can only be stopped if we use a confidence threshold ... how ?
    # CURRENT : should only be reached for extractive terms
    if ( $node->is_leaf ) {
	
	my $node_token = $node->value;

	# check support
	my ( $token_is_extractive , $token_target_supported , $token_reference_supported ) = $this->_token_analysis( $reference_object , $node_token );

	# Note : current we trust all non-extractive tokens
	if ( ! $token_is_extractive ) {
	    $adapted_node = $node->clone;
	    $adapted_node_confidence = 1;
	}
	# attempt to adjust extractively
	elsif( $token_reference_supported ) {

	    my $extractive_replacement_entry = $this->extractive_replacement( $reference_sentence , $node_token );
	   
	    my $extractive_replacement = $extractive_replacement_entry->[ 0 ];
	    my $extractive_replacement_confidence = $extractive_replacement_entry->[ 1 ];

	    $adapted_node = Tree->new( $extractive_replacement );

	    # CURRENT ==> one solution is to look for closest target supported words and check (how ?) for relatedness ...
	    $adapted_node_confidence = $extractive_replacement_confidence;

	}
	# check abstractive support
	# Note : given the previous tests, we never reach this point
	elsif( my $abstractive_support = $this->abstractive_support( $node_token ) ) {
	    # TODO : we need to make a prediction based on the features on the object
	    #        => for now random, better estimate could be empirical probability in corpus of summaries
	    $adapted_node = $node->clone;
	    $adapted_node_confidence = $abstractive_support;
	}
	else {
	    $adapted_node = $node->clone;
	    $adapted_node_confidence = 0;
	}

	# TODO : as a default, clone existing node unless adapted_node_confidence is 0 ?

    }
    # internal nodes: first attempt to adapt full sub-tree, if not proceed recursively. In both cases, compute confidence level
    else {

	# *************************************************************************************************************************
	# verify sub-tree support
	# *************************************************************************************************************************

	my @leaf_nodes = grep { $_->is_leaf } $node->traverse( $node->POST_ORDER );
	my @leaf_nodes_tokens = map { $_->value } @leaf_nodes;

	my $unsupported_count_target = 0;
	my @leaf_nodes_is_extractive = map {
	    my ( $is_extractive , $target_supported , $reference_supported ) = $this->_token_analysis( $reference_object , $_ );
	    if ( ! $target_supported ) {
		$unsupported_count_target++;
	    }
	    $is_extractive;
	} @leaf_nodes_tokens;

	# Note : ideally we should attempt to match since the sub-tree tokens may not appear in the expected order
	# TODO : test with full matching
	if ( ! $unsupported_count_target ) {
	    # Note : for now we assume that this sub-tree is ok, nothing to be done
	    $adapted_node = $node->clone;
	    $adapted_node_confidence = 1;
	}
	else {

	    my @subtree_support_regex_components;
	    for ( my $i=0; $i<=$#leaf_nodes; $i++ ) {
		my $leaf_node_token = $leaf_nodes_tokens[ $i ];
		push @subtree_support_regex_components , $leaf_nodes_is_extractive[ $i ] ? $this->_abstracted_out_regex( $leaf_node_token ) : $leaf_node_token->as_regex ;
	    }
	    
	    my $subtree_support_regex = join( '\s*' , @subtree_support_regex_components );

	    # TODO : generate subtree_support_regex only if there is more than one leaf node
	    if ( ( scalar( @leaf_nodes ) > 1 ) && ( my $matches = $this->target->supports( $subtree_support_regex , raw => 1 , matches => 1 ) ) ) {
		
		# Note : for now we pick the best match
		# TODO : handle all possible matches => generate a tree for each match
		my $best_match = undef;
		my $best_match_score = -1;
		my $best_match_tree = undef;
		foreach my $match (@{ $matches } ) {

		    my $match_score = 1;
		    
		    # We create a clone of the entire sub-tree
		    # We will modify leaf nodes in the clone based on the current set of matches
		    my $match_tree = $node->clone;

		    # assign matches to tokens
		    for ( my $i=0; $i<=$#leaf_nodes; $i++ ) {
			
			# *original* descendant node
			my $descendant_node = $leaf_nodes[ $i ];
			my $descendant_node_is_extractive = $leaf_nodes_is_extractive[ $i ]; 

			# we only focus on extractive nodes
			if ( ! $descendant_node_is_extractive ) {
			    # nothing
			}
			else {

			    # we need to find the corresponding node in the sub-tree clone
			    my @ancestors_index;
			    my $ancestor = $descendant_node;
			    while ( $ancestor->depth < $node->depth ) {
				my $ancestor_parent = $ancestor->parent;
				unshift @ancestors_index , $ancestor_parent->get_index_for( $ancestor );
				$ancestor = $ancestor_parent;
			    }

			    # we now consume the list of indices starting from the cloned sub-tree root
			    my $leaf_node = $match_tree;
			    while( scalar( @ancestors_index ) ) {
				$leaf_node = $leaf_node->children( shift @ancestors_index );
			    }

			    # leaf node value is based on the regex match for this node
			    $leaf_node->set_value( shift @{ $matches } );

			    $match_score *= $this->cost_function( $reference_object , $descendant_node->value , $this->target , $leaf_node->value );

			}
		    }
		 
		    if ( $match_score > $best_match_score ) {
			$best_match = $match;
			$best_match_score = $match_score;
			$best_match_tree = $match_tree;
		    }
   
		}

		affirm { defined( $best_match_tree ) } "at this point we much have a replacement tree";
		$adapted_node = $best_match_tree;
		
	    }
	    else { # we will have to recurse and attempt to match at a lower level

		$adapted_node = Tree->new( $node_value );

		my $confidence_normalize = 0;
		my $confidence_additive = 0;
		my $confidence_multiplicative = 1;
		if ( $node_value eq 'CC' ) {
		    $confidence_additive = 1;
		    $confidence_normalize = 1;
		    $adapted_node_confidence = 0;
		}
		else {
		    $adapted_node_confidence = 1;
		}
		
		# process each child of the current node individually ?
		my @node_children = $node->children;
		my $n_children = scalar( @node_children );
		my $n_children_post = 0;
		foreach my $node_child ( @node_children ) {
		    
		    # recurse
		    my ( $adapted_child , $adapted_child_confidence ) = $this->_adapt_recursively( $reference_sentence , $alignment , $node_child , $depth + 1 );
		    
		    if ( defined( $adapted_child) && $adapted_child_confidence ) {
			$adapted_node->add_child( {} , $adapted_child );
			$n_children_post++;
		    }
		    
		    # relevance probability => cost
		    # => cannot be factored based on individual tokens => could result in dropping everything
		    # TODO : how do we account for depth ?
		    # => average ? => not convincing
		    if ( $confidence_additive ) {
			$adapted_node_confidence += $adapted_child_confidence;
		    }
		    else {
			$adapted_node_confidence *= $adapted_child_confidence;
		    }
		    
		}
		
		if ( $confidence_normalize && $n_children ) {
		    $adapted_node_confidence /= $n_children;
		}
		
		# determine action based on predicted cost ?
		# Note : how often will this actually happen ?
		if ( ! $adapted_node_confidence ) {
		    # we drop this node
		    $adapted_node = undef;
		}
		
	    }

	}
	
	# *************************************************************************************************************************

    }

    return ( $adapted_node , $adapted_node_confidence );

}

sub abstractive_support {

    my $this = shift;
    my $token = shift;

    return $this->global_data->global_count( 'summary' , 1 , lc( $token->surface ) ) / $this->global_data->global_count( 'summary' , 1 );

}

sub _prepare_sequence {
    
    my $sequence = shift;
    my @sequence_tokens = map { lc( $_->surface ) } grep { ! $_->is_punctuation } @{ $sequence->object_sequence };

    return \@sequence_tokens;

}

sub extractive_replacement {

    my $this = shift;
    my $reference_sentence = shift;
    my $token = shift;

    # CURRENT : may want to consider a range of extraction solutions
    # 1 - return closest supported term
    # 2 - regex

    my $reference_object = $reference_sentence->object;
    
    # TODO : how the sequence is generated could depend on the modality (e.g. is it fluent, etc.) ?
    my $reference_sentence_tokens = _prepare_sequence( $reference_sentence );

    # 1 - get list of utterances supporting this token
    my $supporting_utterances = $token->object_support( $reference_object , raw => 0 );

    # 2 - process each utterance independently
    my @extraction_patterns;
    foreach my $supporting_utterance_entry (@{ $supporting_utterances }) {
	
	my $supporting_utterance = $supporting_utterance_entry->[ 0 ];
	my $supporting_utterance_tokens = _prepare_sequence( $supporting_utterance );

	# compute LCS between reference sentence and utterance
	my @lcs = LCS( $reference_sentence_tokens , $supporting_utterance_tokens );

	# turn lcs into an extraction pattern
	my $extraction_pattern = $this->_generate_extraction_pattern( \@lcs , $token );
	if ( $extraction_pattern ) {
	    push @extraction_patterns , $extraction_pattern;
	}

    }

    # 3 - apply extraction patterns to target
    my %candidates;
    foreach my $extraction_pattern (@extraction_patterns) {
	my $matching_target_utterances = $this->target->utterances( pattern => $extraction_pattern );
	foreach my $matching_target_utterance_set (values( %{ $matching_target_utterances } )) {
	    foreach my $matching_target_utterance (@{ $matching_target_utterance_set }) {
		$matching_target_utterance->verbalize =~ m/$extraction_pattern/;
		my $match = $1;
		if ( $match ) {
		    $candidates{ $match }++;
		}
	    }
	}
    }

    # 4 - identify best candidate
    my @sorted_candidates = sort { $candidates{ $b } <=> $candidates{ $a } } keys( %candidates );

    # TODO : can we do better ?
    my $extractive_replacement_entry = [ undef , 0 ];
    if ( $#sorted_candidates > -1 ) {
	my $extractive_replacement_candidate = $sorted_candidates[ 0 ];
	my $extractive_replacement_candidate_confidence = $candidates{ $extractive_replacement_candidate };
	$extractive_replacement_entry = [ $extractive_replacement_candidate , $extractive_replacement_candidate_confidence ];
    }

    return $extractive_replacement_entry;

}

sub _sequence_contains {

    my $this = shift;
    my $lcs = shift;
    my $token = shift;

    return scalar( grep { $token->id eq $_ } @{ $lcs } );

}

sub _generate_extraction_pattern {

    my $this = shift;
    my $lcs = shift;
    my $token = shift;

    # determine whether LCS contains the tokens that we want to map
    if ( ! $this->_sequence_contains( $lcs , $token ) ) {
	# we can skip this utterance
	return undef;
    }
    
    my $context_regex_string = join( '\s*' , map { $_ } grep { $_ ne $token->id } @{ $lcs } );
    my $context_regex = qr/$context_regex_string/i;

    return $context_regex;

}

memoize( '_relevance_probability' );
sub _relevance_probability {

    my $this = shift;
    my $node = shift;

    # Note : this should be a bayesian model of relevance of the current token
    #        => should we proceed recursively ?

    my $relevance_probability = 0;

    return $relevance_probability;

}

__PACKAGE__->meta->make_immutable;

1;
