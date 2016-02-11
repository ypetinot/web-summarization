package GistGraph::Node;

# A Node is an FSA/Word lattice - possibly - enriched with slot operators 
# --> nodes are defined as bags of chunks (as identified by their ids)

# Node genericity: how frequent a node is in the target category
# Node specificity: 1 - genericity, i.e. the more generic a node is the less likely it is to be category specific

use strict;
use warnings;

use List::Util qw/min/;

use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

# fields

# gist graph back-pointer
has 'raw_data' => (is => 'rw', isa => 'Category::Data', required => 0, traits => [ 'DoNotSerialize' ]);

# is this an abstract node ?
has 'is_abstract' => (is => 'rw', isa => 'Num', required => 0, default => 0);

# is this a fully abstracted node ?
# TODO: is this even needed ? could add the root type to all concepts ~
has 'is_abstract_full' => (is => 'rw', isa => 'Num', required => 0, default => 0);

# is this a reduced node
has 'is_reduced' => (is => 'rw', isa => 'Num', required => 0, default => 0);

# name for this node
has 'name' => (is => 'ro', isa => 'Str', required => 0);

# POS for this node
has 'pos' => (is => 'rw', isa => 'Str', required => 0, default => '__unknown_pos__');

# head length
has 'head_length' => (is => 'rw', isa => 'Num', default => 0);

# flags
has 'flags' => (is => 'rw', isa => 'HashRef[Str]', default => sub { {} }, required => 0);

# need to figure out how the FSA/Word Lattice should be represented
#has 'modifiers' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

# all the chunks clustered under this node
has 'raw_chunks' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

# edge verbalizations counts (i.e. unormalized distribution)
has 'verbalizations_counts' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# maps a node to the raw gists in which it appears
has 'node2gists' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# maps a node to its relative position in gists
has 'position' => (is => 'rw', isa => 'Num', default => 0);

# check whether a raw chunk is abstracted by this node
sub contains_chunk {

    my $this = shift;
    my $chunk_id = shift;

    foreach my $raw_chunk_id (@{ $this->raw_chunks() }) {
	if ( $raw_chunk_id == $chunk_id ) {
	    return 1;
	}
    }

    return 0;

}

# add a (raw) chunk to this node
sub add {

    my $this = shift;
    my $chunk_id = shift;

    # each chunk is uniquely associated to a verbalization
    $this->verbalizations_counts()->{ $chunk_id }++; 

    # make sure we're not adding a duplicate chunk
    if ( $this->verbalizations_counts()->{ $chunk_id } > 1 ) {
	return;
    }

    # add new chunk
    push @{ $this->raw_chunks() }, $chunk_id;

    # update head information
    my @chunks = @{ $this->raw_chunks() };
    my $new_head_length = $this->raw_data()->get_chunk( $chunks[0] )->get_number_of_terms;
    my $base_chunk = undef;
    for (my $i=0; $i<scalar(@chunks)-1; $i++) {

	my $base_chunk = $this->raw_data()->get_chunk( $chunks[$i]   );
	my $new_chunk  = $this->raw_data()->get_chunk( $chunks[$i+1] );

	my $base_chunk_length = $base_chunk->get_number_of_terms();
	my $new_chunk_length = $new_chunk->get_number_of_terms();
	
	if ( ! $new_head_length ) {
	    $new_head_length = $base_chunk_length;
	}

	for (my $i=0; $i<$base_chunk_length; $i++) {
	    
	    if ( $i >= $new_chunk_length ) {
		last;
	    }
	    
	    my $base_chunk_term = $base_chunk->get_term($base_chunk_length - $i - 1);
	    my $new_chunk_term = $new_chunk->get_term($new_chunk_length - $i - 1);
	    
	    if ( $base_chunk_term ne $new_chunk_term ) {
		if ( $i + 1 < $new_head_length ) {
		    $new_head_length = $i + 1;
		}
		last;
	    }
	    
	}

    }
    # TODO: make this a type constraint or a trigger ?
    if ( $new_head_length < 1 ) {
	die "Invalid head length: $new_head_length ...";
    }
    $this->head_length($new_head_length);

    # update POS if needed
    # TODO: does this belong here ?
    if ( ! $this->pos() ) {
	my $chunk = $this->raw_data()->get_chunk( $chunk_id );
	$this->pos( $chunk->{'pos'} );
    }

}

# merge two nodes into one
sub merge {

    my $this = shift;
    my $node = shift;
    my $justification = shift;

    print STDERR "Merging ($justification) " . $node->surface_string() . " (" . $node->id() . ") into " . $this->surface_string() . " (" . $this->id() . ")\n";
    
    # update component chunks
    my @new_chunks = map { $this->raw_data()->get_chunk( $_ ); } @{ $node->raw_chunks() };
    foreach my $new_chunk (@new_chunks) {
	
	# add the current chunk to this node
	$this->add( $new_chunk->id() );
	
    }
    
    # update gists occurrences
    my $node_occurrences = $node->get_gist_occurrences();
    foreach my $node_occurrence ( %{ $node_occurrences } ) {
	$this->add_gist_occurrence( $node_occurrence , $node->position(), $node_occurrences->{ $node_occurrence } );
    }

}

# get number of gist occurrences for a given gist
sub get_gist_occurrences {

    my $this = shift;
    my $gist_id = shift;

    if ( defined( $gist_id ) ) {
	return ( $this->node2gists()->{ $gist_id } || 0 );
    }

    return $this->node2gists();

}

# add a gist occurrence for this node
sub add_gist_occurrence {

    my $this = shift;
    my $gist_id = shift;
    my $position = shift;
    my $count = shift || 1;

    my $current_count = $this->count();

    my $current_gist_occurrences = $this->get_gist_occurrences( $gist_id );

    # we never have to look for duplicates ? (shouldn't have to)
    $this->node2gists()->{ $gist_id } = $current_gist_occurrences + $count;

    # update position
    $this->position( ( $this->position() * $current_count + $position * $count ) / ( $current_count + $count ) )

}

# get semantic types for this node
sub semantic_types {

    my $this = shift;
    
    # merge and sort the semantic types of the underlying chunks
    my %semantic_types;
    foreach my $chunk ( @{ $this->raw_chunks() } ) {
	map { $semantic_types{ $_->[3] }++; } @{ $this->raw_data()->get_chunk( $chunk )->semantics() };
    }
    
    my @sorted_semantic_types = sort { $semantic_types{$b} <=> $semantic_types{$a} } keys( %semantic_types );

    return \@sorted_semantic_types;

}

# set a specific label
sub set_label {

    my $this = shift;
    my $label = shift;

    $this->{_labels}->{$label} = 1;

}

# check if a specific label is set
sub has_label {

    my $this = shift;
    my $label = shift;

    return ( $this->{_labels}->{$label} || 0 );

}

# get number of terms for this Node
# (since a Node is a cluster of Chunks, use the head length + average modifier length as the number of terms)
sub get_number_of_terms {

    my $this = shift;

    # TODO: do we really want this ?
    my $average_modifier = 0;

    # compute (expected) number of terms
    my $expected_number_of_terms = $average_modifier + $this->head_length();

    return $expected_number_of_terms;

}

# get head
sub head {

    my $this = shift;

    my @head_data;

    if ( scalar( @{ $this->raw_chunks() } ) ) {
	
	# For now the head is obtained directly from the first (main ?) chunk in this Node
	my $reference_chunk = $this->raw_data()->get_chunk( $this->raw_chunks()->[0] );
	my $effective_head_length = $this->is_reduced() ? 1 : $this->head_length();
	
	for (my $i = 1; $i <= $effective_head_length; $i++) {
	    unshift @head_data, $reference_chunk->get_term_entry( $reference_chunk->get_number_of_terms() - $i );
	}
	
    }

    return \@head_data;

}

# get head string
sub head_string {

    my $this = shift;
    
    my $head = $this->head();
    my $head_string = join( " " , map { $_->{ 'normalized' }; } @{ $head } );

    return $head_string;

}

# identify most likely verbalization for this node
sub mle_verbalization {

    my $this = shift;

    my $verbalization_index = 0;
    my $current_max = 0;
    for (my $i=0; $i<scalar( @{ $this->raw_chunks() } ); $i++) {
	
	my $chunk_id = $this->raw_chunks()->[ $i ];
	if ( $this->verbalizations_counts()->{ $chunk_id } > $current_max ) {
	    $current_max = $this->verbalizations_counts()->{ $chunk_id };
	    $verbalization_index = $i;
	}

    }

    return $verbalization_index;

}

# get surface string
sub surface_string {

    my $this = shift;

    my $surface_string = "__[empty_surface:" . $this->id() . "]__";

    if ( scalar( @{ $this->raw_chunks() } ) ) {

	# The surface string is obtained directly from the first (main ?) chunk in this Node
	my $reference_chunk = $this->raw_data()->get_chunk( $this->raw_chunks()->[0] );

	if ( ! $this->is_reduced() ) {
	    $surface_string = $reference_chunk->terms()->[ $reference_chunk->get_length() - 1 ]->{ 'normalized' };
	}
	else {
	    $surface_string = $reference_chunk->get_surface_string();
	}

    }

    return $surface_string;

}

# get the node's id
sub id {

    my $this = shift;

    my $id = $this->name();

    if ( ! defined($id) ) {
	if ( scalar(@{ $this->raw_chunks() }) ) {
	    $id = $this->raw_chunks()->[0];
	}
	else { # as an alternative, we could generate a random name
	    print STDERR "Warning: Gist Graph Node ($this) has no valid id ...\n";
	    $id = "unknown";
	}
    }

    return $id;

}

# get set of modifiers for this node
sub modifiers() {

    my $this = shift;

    my $head_length = $this->head_length();

    my @modifiers;
    foreach my $chunk_id (@{ $this->raw_chunks() }) {

	my $chunk = $this->raw_data()->get_chunk( $chunk_id );
	push @modifiers, $chunk->get_term( $chunk->get_number_of_terms() - $head_length );

    }

    return \@modifiers;

}


# get number of occurrences
sub count {

    my $this = shift;
    
    my $count = 0;

    foreach my $summary_id (keys (%{ $this->node2gists() })) {

	my $summary_count = $this->node2gists()->{ $summary_id };
	$count += $summary_count;

    }

    return $count;

}

# compute genericity for this node
sub genericity {

    my $this = shift;

    # number of appearances of this node
    my $count = $this->count();

    # number of reference gists
    # TODO: add support for folds
    my $gist_count = scalar( @{ $this->raw_data()->summaries() } );

    # simple estimate for now
    my $genericity = $count / $gist_count;

    return $genericity;

}

# is this a plural (NP) node ?
sub is_plural {

    my $this = shift;

    # for now check wether at least one of the underlying chunk ends with an NNS term
    foreach my $chunk_id (@{ $this->raw_chunks() }) {
	
	my $chunk = $this->raw_data()->get_chunk( $chunk_id );
	my $last_term = $chunk->get_term_entry( $chunk->get_number_of_terms() - 1 );
	if ( $last_term->{'pos'} =~ m/NNS/ ) {
	    return 1;
	}
	
    }

    return 0;

}

# get specificity for this node
# TODO: we can attempt to improve the genericity prior, for instance by incorporating hierarchical information
sub specificity {

    my $this = shift;

    return 1 - $this->genericity();

}

# sub add flag to this node
sub add_flag {

    my $this = shift;
    my $flag_name = shift;

    $this->flags()->{ $flag_name } = 1;

}

# check whether a particular flag is set for this node
sub has_flag {

    my $this = shift;
    my $flag_name = shift;

    return defined($this->flags()->{ $flag_name });

}

=pod
# extract cluster contexts
sub _extract_cluster_contexts {

    my $cluster = shift;
    my $summary = shift;
    my $summary_node_ids = shift;

    # TODO: do we have interest in using the plain summary context as well ? (i.e. structural content patterns).

    my %contexts;

    my $cluster_id = $cluster->id();
    for (my $i=0; $i<scalar(@{ $summary_node_ids }); $i++) {

	my $summary_chunk = $summary_node_ids->[$i];

	if ( $summary_chunk == $cluster_id ) {
	    
	    my $prev = "";
	    if ( $i > 0 ) {
		$prev = $summary_node_ids->[$i-1];
	    }

	    my $next = "";
	    if ( $i < scalar(@{ $summary_node_ids }) - 1 ) {
		$next = $summary_node_ids->[$i+1];
	    }

	    my $context = join(" ", $prev, $next);
	    $contexts{$context}++;

	}

    }

    return \%contexts;

}
=cut

# verbalize this node (either deterministically if a verbalization id is given, or as a sample from the verbalization distribution)
sub verbalize {

    my $this = shift;
    my $verbalization_index = shift;

    if ( scalar( @{ $this->raw_chunks() } ) ) {

	my $target_index = $verbalization_index;
	
	if ( ! defined( $target_index ) ) {
	    # for now
	    $target_index = 0;
	}
	
	return $this->raw_data()->get_chunk( $this->raw_chunks()->[ $target_index ] )->get_surface_string();

    }

    return "";

}

# get (concept) distribution associated with this node
sub distribution {
    
    my $this = shift;

    my $normalization_factor = $this->count();
    
    # for now the concept distribution is defined over unique strings
    # TODO: map chunks to regular expressions for easy matching, also make modifiers optional

    my $distribution = {};
    for (my $i=0; $i<scalar( @{ $this->raw_chunks() } ); $i++) {
	
	my $chunk_id = $this->raw_chunks()->[ $i ];
	$distribution->{ $chunk_id } = $this->verbalizations_counts()->{ $chunk_id }; 

    }
    
    # normalize distribution
    map { $distribution->{ $_ } /= $normalization_factor; } keys( %{ $distribution } );

    return $distribution;

}

no Moose;

1;
