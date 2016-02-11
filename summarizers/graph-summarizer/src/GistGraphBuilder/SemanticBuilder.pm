package GistGraphBuilder::SemanticBuilder;

# Semantic Gist Graph
# Gist Graph where nodes can be merged based on surface and semantic information

use strict;
use warnings;

use Moose;

use GistGraph;
extends 'GistGraphBuilder';

# Class to manage Gist Graph --> GistGraph
# Factory classes: ClusterableGistGraph / SemanticGistGraph in charge of constructing the graph
# both use GistGraphBuilder class ?

# Logic:
# 0 - any chunk that appear multiple times (10% ?) is deemed relevant to the category

# For those chunks that do not match this constraint:
# 1 - attempt to map to wikipedia entry then to concept
# 2 - if failed, attempt to map last token to dicitionary entry

sub merge_identical_nodes {

    my $that = shift;
    my $gist_graph = shift;

    my %surface2node;

    map {

	my $normalized_surface_form = $_->surface_string();
	if ( ! defined( $surface2node{ $normalized_surface_form } ) ) {
	    $surface2node{ $normalized_surface_form } = [];
	}

	push @{ $surface2node{ $normalized_surface_form } } , $_;

    } values( %{ $gist_graph->nodes() } );

    # now merge identical nodes
    foreach my $surface (keys( %surface2node )) {
	
	my @cluster_nodes = @{ $surface2node{ $surface } };
	
	if ( scalar( @cluster_nodes ) > 1 ) {
	    print STDERR "Merging nodes sharing the same surface form ($surface)\n";
	    $gist_graph->merge_nodes( \@cluster_nodes , 'surface-duplicates' );
	}

    }

}

sub process {

    my $that = shift;
    my $gist_graph = shift;

    # 0 - merge nodes that share the same surface form
    # TODO: move this up to the parent class ?
    $that->merge_identical_nodes( $gist_graph );

    my $prevalence_threshold = 0.1;

    my $gist_count = $gist_graph->raw_data()->get_gist_count();

    my %reduced2nodes;

    # 1 - abstract all nodes that appear in less than X% of gists and for which a semantic type has been found
    # 2 - all remaining nodes that appear in less than X% of gists are reduced up to coocurrence constraints
    map {

	# compute node prevalence
	my $prevalence = $_->count() / $gist_count;

	my $semantic_types = $_->semantic_types();

	if ( $prevalence < $prevalence_threshold ) {

	    if ( scalar(@{ $_->semantic_types() } ) ) {
		
		print STDERR "[Rare Node ($prevalence)] - will abstract node (" . $_->surface_string() . ")\n";
		$_->is_abstract( 1 );
		
	    }
	    else {

		$_->is_reduced( 1 );
		my $reduced_form = $_->surface_string;
		
		if ( ! defined( $reduced2nodes{ $reduced_form } ) ) {
		    $reduced2nodes{ $reduced_form } = [];
		}
		push @{ $reduced2nodes{ $reduced_form } } , $_;
		
	    }

	}

    } values( %{ $gist_graph->nodes() } );

    # 3 - merge reduced nodes
    # TODO: check for gist constraints ?
    foreach my $reduced_form (keys( %reduced2nodes )) {

	my @cluster_nodes = @{ $reduced2nodes{ $reduced_form } };
	
	if ( scalar( @cluster_nodes ) > 1 ) {
	    print STDERR "[Reduced form: $reduced_form] - will cluster nodes ...\n";
	    $gist_graph->merge_nodes( \@cluster_nodes , 'reduced-semantic-match' );
	}

    }

    # 4 - all remaining nodes that appear in less than X% of gists and are not dictionary words are abstracted out to the root concept
    map {
	
	# compute node prevalence
	my $prevalence = $_->count() / $gist_count;

	if ( $prevalence < $prevalence_threshold ) {
	    
	    if ( $_->is_reduced( 1 ) ) {

		if ( ! $_->head()->[0]->{ 'in_dictionary' } ) {
		    $_->is_abstract_full( 1 );
		}

	    }

	}

    } values( %{ $gist_graph->nodes() } );

}

# similarity function based on semantic data
sub _cluster {

    my $cluster1 = shift;
    my $cluster2 = shift;

=pod
    # for tokens that could not be mapped to a Wikipedia concept, make sure they are at least valid dictionary words
    if ( ! scalar( @{ $semantics } ) ) {
	
	# force reduction to a single token ?
	
	my $has_dictionary_entry = 1;
	if ( $has_dictionary_entry ) {
	    
	}
	else { # Mark token as "Type::Unknown"
	    
	}
	
    }
=cut

}

=pod
# abstract a node
sub abstract_node {

    
    my $chunk_semantic_types = $id2chunk{ $chunk_id }->{'semantictype'};

    # abstract if this a unique chunk
    if ( $chunk_type eq 'np' && $id2chunk{ $chunk_id }->{'count'} == 1 ) {
	
	my $chunk_semantic_type = "[[Type::Unknown]]";
	if ( scalar( @{ $chunk_semantic_types } ) ) {
	    $chunk_semantic_type = $chunk_semantic_types->[0];
	}
	
	my $type_count = $type2count{ $chunk_semantic_type }++;
	my $id = join( "::" , $chunk_semantic_type, $type_count );
	if ( ! defined( $chunks{ $id } ) ) {
	    $chunk = new AbstractChunk( 'id' => $id, version => $type_count , 'type' => $chunk_semantic_type );
	}
	print STDERR join(" >> " , $chunk_id, $id, $id2chunk{ $chunk_id }) . "\n";
	$chunk_id_final = $id;
	
    }
    
}
=cut

no Moose;

1;
