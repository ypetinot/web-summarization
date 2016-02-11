#!/usr/bin/env perl

# TODO : to be removed

# 1 - build raw gist graph for all the test URLs

use strict;
use warnings;

use Category::Folds;
use Web::Summarizer::Graph2;
use Web::Summarizer::Graph2::Definitions;

use Clone qw/clone/;
use Digest::MD5 qw/md5_hex/;
use File::Path qw/make_path/;
use Getopt::Long;
use Graph;
use Graph::Directed;
use Graph::Undirected;
use Graph::Writer::Dot;
use Graph::Writer::XML;
use JSON;
use List::Util qw/max min sum/;
use List::MoreUtils qw/uniq/;
use Statistics::Basic qw(:all);

my $fold_id = undef;

my $do_abstraction = 0;
my $apply_slotting = 0;
my $do_incremental = 0;

my $mode = undef;
my $minimum_importance = undef;
my $maximum_importance = undef;
my $output_directory = undef;
my $reference_cluster_limit = undef;
my $term = undef;

my $MODE_TERMS = "terms";
my $MODE_SALIENT = "salient";

Getopt::Long::Configure ("bundling");

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if ( ! defined( $fold_id ) );
pod2usage(-exitstatus => 0) if ( $#ARGV < 0 );

my $edge_features = [ $Web::Summarizer::Graph2::Definitions::FEATURE_EDGE_TARGET_FREQUENCY ,
		      $Web::Summarizer::Graph2::Definitions::FEATURE_SOURCE_TARGET_FREQUENCY ,
		      $Web::Summarizer::Graph2::Definitions::FEATURE_SINK_TARGET_FREQUENCY
];

my %edge2featureIds;
my %feature2id;
my %id2feature;
my $feature_count = 0;

# category base
my $category_base = shift @ARGV;

if ( ! -f $category_base ) {
    die "Category base does not exist: $category_base";
}

# 1 - load fold
my $fold = Category::Folds->new( 'category_data_base' => $category_base )->load()->get_fold( $fold_id );

my %tokens2count;

my %pre_frequencies;
my %frequencies;

my %global;
my %idfs;
my %importances;
my %unique_appearances;

my $training_entries = $fold->fold_data();
if ( $reference_cluster_limit && ( $reference_cluster_limit < scalar( @{ $training_entries } ) ) ) {
    splice @{ $training_entries }, $reference_cluster_limit;
}

my $testing_entries = $fold->test_data();

# 1 - create new directed graph
my $reference_graph = Graph::Directed->new;
$reference_graph->set_graph_attribute( 'node_map' , encode_json( {} ) );
my $reference_entries = $training_entries;
my %reference_stats;

# 2 - collect all reference paths (reference gists)
my @reference_paths;
foreach my $reference_entry (@{ $reference_entries }) {

    my $reference_url = $reference_entry->url();
    my $reference_gist = $reference_entry->get_field( 'summary' );
    my $reference_gist_sequence = _generate_sequence( $reference_gist );

    # update sequence stats
    foreach my $token (@{ $reference_gist_sequence }) {
	$pre_frequencies{ lc($token) }++;
    }

    push @reference_paths, [ $reference_url , $reference_gist_sequence , $reference_entry ];

}

my $reference_paths_count = scalar( @reference_paths );

# 3 - abstraction
if ( $do_abstraction ) {

    print STDERR "Abstracting paths ...\n";

    my %token2type;

    foreach my $reference_path (@reference_paths) {

	my $reference_url = $reference_path->[ 0 ];
	my $reference_gist_sequence = $reference_path->[ 1 ];
	my $reference_entry = $reference_path->[ 2 ];

	for (my $i=0; $i<scalar(@{ $reference_gist_sequence }); $i++) {

	    my $i_copy = $i;

	    my $token = $reference_gist_sequence->[ $i ];

	    my @updated_tokens;
	    my @original_tokens;
	    

	    # Auto adjust threshold ?
	    if ( $pre_frequencies{ lc( $token ) } / $reference_paths_count > 0.25 ) {
		# frequent term, do nothing
	    }
	    elsif ( $token2type{ $token } eq $Web::Summarizer::Graph2::Definitions::POS_VERB ) {
		# nothing
	    }
	    elsif ( $token2type{ $token } eq $Web::Summarizer::Graph2::Definitions::POS_ADVERB ) {
		push @original_tokens, $token;
		push @updated_tokens, $Web::Summarizer::Graph2::Definitions::POS_ADVERB;
	    }
	    elsif ( $token2type{ $token } eq $Web::Summarizer::Graph2::Definitions::POS_ADJECTIVE ) {
		push @original_tokens, $token;
		push @updated_tokens, $Web::Summarizer::Graph2::Definitions::POS_ADJECTIVE;
	    }
	    else {
		# scan for Named Entities
		while ( $token =~ m/^[A-Z]\w+/s ) {
		    push @original_tokens, $token;
		    push @updated_tokens, "<NAMED_ENTITY_SLOT>";
		    $token = $reference_gist_sequence->[ ++$i ];
		}
	    }
	    
	    if ( scalar( @updated_tokens ) ) {

		my @updated_tokens_copy = @updated_tokens;
		my @original_tokens_copy = @original_tokens;
		
		for (my $j=1; $j<scalar(@updated_tokens_copy); $j++) {
		    $reference_gist_sequence->[ $i_copy + $j ] = undef;
		}

		my $token_previous = $i_copy ? clone( $reference_gist_sequence->[ $i_copy - 1 ] ) : undef;
		my $token_next = ( $i <= $#{ $reference_gist_sequence } ) ? clone( $reference_gist_sequence->[ $i ] ) : undef;
		
		# Keep track of slot characteristics
		$reference_gist_sequence->[ $i_copy ] = [
		    \@updated_tokens_copy,
		    $token_previous,
		    $token_next,
		    $reference_url,
		    \@original_tokens_copy
		    ];

	    }

	    # reset cursor variables
	    @updated_tokens = ();

	}

    }

}

# 4 - Case normalization
print STDERR "Normalizing paths ...\n";
foreach my $reference_path (@reference_paths) {

    my $reference_url = $reference_path->[ 0 ];
    my $reference_gist_sequence = $reference_path->[ 1 ];
    my $reference_entry = $reference_path->[ 2 ];

    for (my $i=0; $i<scalar(@{ $reference_gist_sequence }); $i++) {
	
	my $current_token = $reference_gist_sequence->[ $i ];
	if ( defined( $current_token ) && ! ref( $current_token ) ) {
	    $reference_gist_sequence->[ $i ] = lc( $current_token );
	}

    }
	
}

# 5 - Real stats
print STDERR "Computing graph stats ...\n";
foreach my $reference_path (@reference_paths) {

    my $reference_url = $reference_path->[ 0 ];
    my $reference_gist_sequence = $reference_path->[ 1 ];
    my $reference_entry = $reference_path->[ 2 ];

    # update sequence stats
    foreach my $token (@{ $reference_gist_sequence }) {
	if ( defined( $token ) && ! ref( $token ) ) {
	    $frequencies{ $token }++;
	}
    }

}

=pod
# 3 - Abstract reference paths
my $slot_count = 1;
foreach my $reference_path (@reference_paths) {

    my $reference_url = $reference_path->[ 0 ];
    my $reference_gist_sequence = $reference_path->[ 1 ];
    my $reference_entry = $reference_path->[ 2 ];

    my $from = undef;
    my $to = undef;

    for (my $i=0; $i<scalar(@{ $reference_gist_sequence }); $i++) {
	
	my $token = $reference_gist_sequence->[ $i ];
	
	# We're looking for unique tokens
	if ( $frequencies{ $token } != 1 || ($token =~ m/\p{Punct}/) ) {
	#if ( $frequencies{ $token } / $reference_paths_count > 0.5 ) {
	    if ( defined( $from ) ) {
		# TODO: should we also specialize the slot boundaries ?
		#if ( $from > 1 ) {
		#    $reference_gist_sequence->[ $from - 1 ] .= "/" . ( $slot_count++ );
		#}
		$reference_gist_sequence->[ $from ] = "[" . join("::", $reference_gist_sequence->[ $from - 1 ], $reference_gist_sequence->[ $to + 1 ]) . "]";
		for (my $j=$from+1; $j<=$to; $j++) {
		    $reference_gist_sequence->[ $j ] = undef;
		}
		$from = undef;
		$to = undef;
	    }
	    next;
	}
	elsif ( ! defined( $from )
		#&& _appears( $reference_entry , $reference_gist_sequence->[ $i ] ) 
	    ) {
	    $from = $i;
	}
	else {
	    # nothing, we keep going ...
	}

	$to = $i;

    }

}
=cut

# post process stats
# TODO

# 3 - create slots if requested (this effectively has the highest priority to achieve multi-sentence alignment)
# We're doing this for reference gists only ? What about other well-formed sentences ?
if ( $apply_slotting ) {

    # 2.1 - generate all content pairs appearing at least twice
    my $candidates = _find_slot_candidates( \@reference_paths );

    # 2.2 - rank candidates by decreasing number of sequences in which they occur
    # --> prioritize slots to guarantee the most important ones are detected
    # --> discard overlapping slots
    my @sorted_candidate_keys = sort { scalar( @{ $candidates->{ $b }->{ 'paths' } } ) <=> scalar( @{ $candidates->{ $a }->{ 'paths' } } ) } ( keys %{ $candidates } );

    # 2.2 - determine if pair is a potential slot
    foreach my $candidate_key (@sorted_candidate_keys) {
	
	my $path_entries = $candidates->{ $candidate_key }->{ 'paths' };
	my $slot_length = $candidates->{ $candidate_key }->{ 'length' };
	my @path_lengths = map { scalar( @{ $_->[ 3 ] } ) } @{$path_entries};
	
	my $min_path_length = min @path_lengths;
	my $max_path_length = max @path_lengths;

	# 2.2.1 - largest separation length cannot be more than twice the smallest separation length
	if ( 2 * $min_path_length < $max_path_length ) {
	    next;
	}

	# 2.2.2 - more filtering ?
	# TODO

	# this is a valid slot
	my $slot = _insert_slot( $reference_graph , $candidate_key , $path_entries );

	# 2.3 - Substitute slots in reference paths
	foreach my $reference_path (@reference_paths) {

	    foreach my $path_entry (@{ $path_entries }) {
	    
		my $path_id = $path_entry->[ 0 ];
		my $path_from = $path_entry->[ 1 ];
		my $path_to = $path_entry->[ 2 ];
		my $path_sequence = $path_entry->[ 3 ];
		    
		# make sure we're not overlapping with a previous applied slot
		# TODO: optimize this step
		my $has_overlap = 0;
		for (my $i=($path_from+1); $i<=($path_to-1); $i++) {
		    if ( ( ! defined( $reference_path->[1]->[ $i ] ) ) || ( $reference_path->[1]->[ $i ] ne $path_sequence->[ $i - $path_from - 1 ] ) ) {
			$has_overlap = 1;
		    }
		}

		# TODO: do we want to re-evaluate the relevance of the slot if this happens ?
		if ( $has_overlap ) {
		    print STDERR ">> Slot overlap - will not apply slot to $path_id / $path_from / $path_to ...\n";
		    next;
		}

		# must match target length
		if ( $path_to - $path_from - 1 != $slot_length ) {
		    print STDERR ">> Does not match slot length ...\n";
		    next;
		}

		# mark path locactions as blocked in original sequences
		$reference_path->[ 1 ]->[ $path_from + 1 ] = $slot;
		for (my $i=($path_from + 2); $i<=($path_to-1); $i++) {
		    $reference_path->[ 1 ]->[ $i ] = undef;
		}

	    }
	    
	}
	
    }

}

# Problematic is on how should frequent nodes be shared / not shared --> unique nodes are not a problem
# [1] --> this is why we start building from specific nodes

# 1 - Each gist must map to a cycle-free path
# 2 - Can connect an existing frequent node to a less frequent node if a neighbor of this frequent node is not compatible with the less frequent node

if ( $do_incremental ) {

    my $nodes_status = {};
    my $max_frequency = max( values( %frequencies ) );

    my @gist_states = map { {} } @reference_paths;

    for (my $frequency_level=1; $frequency_level<=$max_frequency; $frequency_level++) {

	# Introducing content at frequency level $frequency_level

	for (my $i=0; $i<scalar(@reference_paths); $i++) {

	    my $reference_path = $reference_paths[ $i ];
	    my $gist_state = $gist_states[ $i ];

	    my $reference_url = $reference_path->[ 0 ];
	    my $reference_gist_sequence = $reference_path->[ 1 ];
	    my $reference_entry = $reference_path->[ 2 ];

	    for (my $j=0; $j<scalar(@{ $reference_gist_sequence }); $j++) {
		
		my $current_token = $reference_gist_sequence->[ $j ];
		if ( ref( $current_token ) ) {
		    next;
		}

		my $current_token_frequency = $frequencies{ $current_token };
		
		my $previous = ( $j != 0 ) ? $reference_gist_sequence->[ $j - 1] : undef;
		my $next = ( $j != (scalar(@{ $reference_gist_sequence }) - 1) ) ? $reference_gist_sequence->[ $j + 1 ] : undef;

		if ( $current_token_frequency > $frequency_level ) {
		    # We have to wait ...
		    next;
		}

		if ( $current_token_frequency == $frequency_level ) {

		    my @filter;
		    if ( $previous ) { push @filter, $previous; }
		    if ( $next ) { push @filter, $next; }

		    # Insert node for this term
		    my $node = _insert_node( $reference_graph , $current_token , $reference_url , $gist_state , \@filter );
		    $reference_gist_sequence->[ $j ] = [ $node ];

		    # If the neighboring nodes already exist, create all necessary edges
		    if ( ref( $previous ) ) {
			_insert_edge( $reference_graph , $reference_url , $previous->[ 0 ] , $node );
		    }
		    if ( ref( $next ) ) {
			_insert_edge( $reference_graph , $reference_url , $node , $next->[ 0 ] );
		    }

		}

	    }

	}
	
    }

}


#### At this point all the slots have been inserted in the graph
#### We are now ready to insert the reference paths
## 4 - populate graph with reference gists paths
print STDERR "Inserting paths ...\n";
foreach my $reference_path (@reference_paths) {
    
    my $reference_url = $reference_path->[ 0 ];
    my $reference_gist_sequence = $reference_path->[ 1 ];
    my $reference_entry = $reference_path->[ 2 ];

    # update path with final sequence of nodes !
    my $updated_reference_gist_sequence = _insert_path( $reference_graph , $reference_url , $reference_gist_sequence );

    if ( $DEBUG ) {
	_check_path( $reference_graph , $updated_reference_gist_sequence , $reference_url );
    }

    $reference_path->[ 1 ] = $updated_reference_gist_sequence;

}

# 5 - populate graph with reference contents paths
#foreach my $reference_entry (@{ $reference_entries }) {
#    _insert_reference_content( $reference_graph , \%reference_stats , $reference_entry->url() , _generate_sequence( $reference_entry->get_field( 'content.phrases' ) ) );
#}

# 6 - post slotting (to group slots for which context may vary) ?
# TODO ?

# Collect additional stats that will be required for node/edge feature generation
print STDERR "Computing more stats ...\n";
my $field_content_phrases = 'content.phrases';
my %node2appearances;
foreach my $training_entry (@{ $training_entries }) {

    field_loop: foreach my $field ( $field_content_phrases ) {

	my $data = $training_entry->get_field( $field );
	foreach my $node ($reference_graph->vertices()) {

	    if ( ! defined( $node2appearances{ $node } ) ) {
		$node2appearances{ $node } = {};
	    }
	    
	    # If this node is a slot, we are looking for the value of its filler for the target entry
	    my $node_verbalization = $node;
	    if ( ref( $node ) ) {
		$node_verbalization = join( " " , @{ $node->[ 3 ]->{ $training_entry->url() } } );
	    }

	    # Look for occurrences of $node in $field
	    if ( $data =~ m/${node_verbalization}/sgi ) {
		$node2appearances{ $node }{ $field }++;
		next field_loop;
	    }

	    foreach my $successor ($reference_graph->successors( $node )) {

		my $outgoing_edge = [ $node , $successor ];

	    }

	}

    }

}

print STDERR "Generating gist graph ...\n";
my $final_gist_graph = _generate_gist_graph( $reference_graph , \@reference_paths , \%reference_stats );

print STDERR "Generating testing data ...\n";
my $output_directory_test = join("/", $output_directory, "test");
foreach my $testing_entry (@{ $testing_entries }) {

    my $target_url = $testing_entry->url();
    my $output_directory_testing_entry = join("/", $output_directory_test, md5_hex( $target_url ));
    make_path( $output_directory_testing_entry );

    # specialize grap for the target URL
    my $specialized_graph = _specialize_gist_graph( $final_gist_graph , $testing_entry );

    # generate raw features for testing entries

    # generate edge features
    print STDERR "Generating raw edge features for test entries ...\n";
    my %edge_features;
    foreach my $edge ( $specialized_graph->edges() ) {

	# compute features for the current wrt to the testing entry
	# does this apply to edges involving slot locations ???
	my $current_edge_features = _generate_edge_features( $specialized_graph , $testing_entry , $edge , $edge_features );

	map { $edge_features{ $_ } = $current_edge_features->{ $_ }; } keys( %{ $current_edge_features } );

    }

    # Write out specialized graph
    print STDERR "\tWriting out specialized gist graph for $target_url ...\n";
    my $output_file = join("/", $output_directory_testing_entry, "graph.raw");
    my $output_file_dot = join("/", $output_directory_testing_entry, "graph.raw.dot");
    my $writer_dot = Graph::Writer::Dot->new();
    my $writer = Graph::Writer::XML->new();
    $writer->write_graph($specialized_graph, $output_file);
    $writer_dot->write_graph($specialized_graph, $output_file_dot);

    # Write out test data ?
    # --> to be evaluted using text similarity measures (i.e. ROUGE) ... not necessary ?
    my $test_edge_features_file = join("/", $output_directory_testing_entry, "features");
    open TEST_EDGE_FEATURES, ">$test_edge_features_file" or die "Unable to create test edge features file ($test_edge_features_file";
    print TEST_EDGE_FEATURES join("\t", $target_url, encode_json( \%edge_features )) . "\n";
    close TEST_EDGE_FEATURES;
   
}

sub _specialize_gist_graph {

    my $reference_graph = shift;
    my $target_entry = shift;

    my $specialized_graph = $reference_graph->deep_copy();

    # 1 - replace slots with alternate verbalization paths
    # TODO

    # 2 - what else ?

    return $specialized_graph;

}

sub _appears {

    my $entry = shift;
    my $token = shift;

    my $entry_content = $entry->get_field( 'content.phrases' ) || '';
    if ( $entry_content =~ m/$token/sgi ) {
	return 1;
    }

    my $entry_anchortext = $entry->get_field( 'anchortext.sentence' ) || '';
    if ( $entry_anchortext =~ m/$token/sgi ) {
	return 1;
    }

    return 0;

}

sub _find_slot_candidates {

    my $path_entries = shift;

    my %directed_pairs;

    # 1 - scan all entries and keep track of directed pairs, appearance counts and separating paths
    foreach my $path_entry (@{ $path_entries }) {

	my $path_id = $path_entry->[ 0 ];
	my $path_sequence = $path_entry->[ 1 ];

	my $string_token_count = scalar(@{ $path_sequence });
	
	for (my $i=0; $i<$string_token_count; $i++) {

	    # Note: largest separation length is at least 1 and no more than 25% the length of the associated gist
	    for ( my $j=$i+2; ( ( $j<$string_token_count ) && ( ( $j - $i ) < 0.25 * $string_token_count ) ); $j++ ) {

		my $token1 = $path_sequence->[ $i ];

		my $pair_key = join("::", $path_sequence->[ $i ], $path_sequence->[ $j ]);

		if ( ! defined( $directed_pairs{ $pair_key } ) ) {
		    $directed_pairs{ $pair_key } = {
			'from' => $path_sequence->[ $i ],
			'to'   => $path_sequence->[ $j ],
			'paths' => []
		    };
		}
		
		my @copy = @{ $path_sequence };
		my @path = splice @copy , ($i+1), ($j-$i-1);
		push @{ $directed_pairs{ $pair_key }->{ 'paths'} }, [$path_id , $i , $j , \@path];

	    }

	}
       
    }

    # Remove pairs that occur only once
    foreach my $pair_key (keys(%directed_pairs)) {
	if ( scalar( @{ $directed_pairs{ $pair_key }->{ 'paths' } } ) <= 1 ) {
	    delete $directed_pairs{ $pair_key };
	}
    }

    # Filtering
    foreach my $pair_key (keys(%directed_pairs)) {

	my $pair_data  = $directed_pairs{ $pair_key };
	my $pair_from  = $pair_data->{ 'from' };
	my $pair_to    = $pair_data->{ 'to' };
	my $pair_paths = $pair_data->{ 'paths' };

	my %variations2seen;
	my @variations = grep { defined( $_ ); } map {
	    my $variation_key = join(" ", @{ $_->[ 3 ] });
	    if ( defined( $variations2seen{ $variation_key } ) ) {
		undef;
	    }
	    else {
		$variations2seen{ $variation_key } = 1;
		$_;
	    }
	} @{ $pair_paths };

	my $keep_pair = 1;

	# Remove pairs for which there is only one intervening path
	if ( scalar(@variations) < 3 ) {
	    $keep_pair = 0;
	}
	else {

	    # Average frequency of intermediate terms, must be lower than surrounding terms
	    my @frequency_maxima;
	    foreach my $variation (@variations) {
		
		my $frequency_sum = 0;
		my $frequency_maximum = max( map { $frequencies{ $_ }; } @{ $variation->[ 3 ] } );
		
		push @frequency_maxima, $frequency_maximum;
		
	    }
	    my $pair_intervening_path_frequency_max = max( @frequency_maxima );
	    my $from_frequency = $frequencies{ $pair_from };
	    my $to_frequency = $frequencies{ $pair_to };
	    if ( 
		( ( $pair_from ne $Web::Summarizer::Graph2::Definitions::NODE_BOG ) && ( $pair_intervening_path_frequency_max >= $from_frequency ) ) ||
		( ( $pair_to ne $Web::Summarizer::Graph2::Definitions::NODE_EOG ) && ( $pair_intervening_path_frequency_max >= $to_frequency ) )
		) {
		$keep_pair = 0;
	    }
   
	}
	
	if ( ! $keep_pair ) {
	    delete $directed_pairs{ $pair_key };
	}
	else {
	    # set target length for slot location
	    $directed_pairs{ $pair_key }->{ 'length' } = median( map { length( @{ $_ } ) } @variations );
	}

    }
    
    
    # Move additional filtering steps here ?
    # TODO

    return \%directed_pairs;

}

sub _encode_url {

    my $url = shift;
    
    my $encoded_url = $url;
    while ( $encoded_url =~ s/[[:punct:]]+//sg ) {}

    return $encoded_url;

}

sub _generate_gist_graph {

    my $reference_graph = shift;
    my $reference_paths = shift;
    my $reference_stats = shift;

    # Duplicate reference graph
    my $gist_graph = $reference_graph->deep_copy();

=pod
    # 5 - populate graph with target content unigrams
    foreach my $target_url_unigram (keys %{ $target_url_unigrams }) {
	
	# We seek unigram that can be used as fillers for template slots
	foreach my $slot_node (@slot_nodes) {

	    if ( _compatible_slot( $slot_node , $target_url_unigram ) ) {
		_insert_slot_filler( $slot_node , $target_url_unigram );
	    }

	}

    }
=cut

    # Write out reference paths
    print STDERR "\tWriting out reference paths and features ...\n";
    # TODO: should we only one - global - file ? / i.e. global graph ?
    my $output_file_paths = join("/", $output_directory, "paths");
    my $output_file_features = join("/", $output_directory, "features");
    open OUTPUT_FILE_FEATURES, ">$output_file_features" or die "Unable to create features file ($output_file_features): $!";
    open OUTPUT_FILE_PATHS, ">$output_file_paths" or die "Unable to create paths file ($output_file_paths): $!";
    foreach my $reference_path (@{ $reference_paths }) {
	
	my $reference_url = $reference_path->[0];
	my $reference_sequence = $reference_path->[1];
	my $reference_entry = $reference_path->[2];

	if ( $DEBUG ) {
	    _check_path( $gist_graph , $reference_sequence , $reference_url );
	}

	print OUTPUT_FILE_PATHS join("\t", $reference_url , grep{ defined( $_ ); } @{ $reference_sequence }) . "\n";

	print STDERR "\t\tGenerating features for path $reference_url ...\n";
	my $features = _generate_features( $gist_graph , $edge_features , $reference_entry );
	print OUTPUT_FILE_FEATURES join("\t", $reference_url, encode_json( $features ) ) . "\n";

    }
    close OUTPUT_FILE_PATHS;
    close OUTPUT_FILE_FEATURES;
 
    # Write out feature definitions
    print STDERR "\tWriting out feature definitions ...\n";
    my $output_file_features_definition = join("/", $output_directory, "features.definition");
    open OUTPUT_FILE_FEATURES_DEFINITION, ">$output_file_features_definition" or die "Unable to create features definition file ($output_file_features_definition): $!";
    foreach my $feature_name (keys( %feature2id )) {
	print OUTPUT_FILE_FEATURES_DEFINITION join("\t", $feature_name, $feature2id{ $feature_name }) . "\n";
    }
    close OUTPUT_FILE_FEATURES_DEFINITION;

    # Write out feature types
    my $output_file_feature_types = join("/", $output_directory, "features.types");
    open OUTPUT_FILE_FEATURE_TYPES, ">$output_file_feature_types" or die "Unable to create feature types file ($output_file_feature_types): $!";
    foreach my $edge_feature (@{ $edge_features }) {
	print OUTPUT_FILE_FEATURE_TYPES join("\t", $edge_feature) . "\n";
    }
    close OUTPUT_FILE_FEATURE_TYPES;

    print STDERR ">> done generating raw gist graph !\n\n";
    
    return $gist_graph;

}

sub _feature_2_id {

    my $edge = shift;
    my $feature_name = shift;
 
    my $edge_key = Web::Summarizer::Graph2->_edge_key( $edge );
    my $feature_key = join("::", $edge_key, $feature_name);
  
    if ( ! defined( $feature2id{ $feature_key } ) ) {
	my $new_id = $feature_count++;
	$feature2id{ $feature_key } = $new_id; 
	$id2feature{ $new_id } = $feature_name;
	push @{ _edge_feature_ids( $edge ) } , $new_id ;
    }

    return $feature2id{ $feature_key };

}

sub _edge_feature_ids {

    my $edge = shift;

    my $edge_key = Web::Summarizer::Graph2->_edge_key( $edge );

    if ( ! defined( $edge2featureIds{ $edge_key } ) ) {
	$edge2featureIds{ $edge_key } = [];
    }

    return $edge2featureIds{ $edge_key };

}

# Generate features for the target entry
# These are not final features, but rather features conditioned on the presence of the associated edge in the target path
sub _generate_features {

    my $graph = shift;
    my $edge_features = shift;
    my $entry = shift;

    my %feature_values;

    # edge-dependent features
    my @edges = $graph->edges();
    foreach my $edge (@edges) {

	my $local_feature_values = _generate_edge_features( $graph , $entry , $edge , $edge_features );
	map { $feature_values{ $_ } = $local_feature_values->{ $_ }; } keys( %{ $local_feature_values } );

    }

    return \%feature_values;
   
}

sub _path_to_edges {

    my $path = shift;
    my @edges;

    for (my $i=0; $i<scalar(@{ $path }) - 1; $i++) {
	push @edges, [ $path->[ $i ] , $path->[ $i+1 ] ];
    }

    return @edges;

}

# Generate all features for a specific graph edge
sub _generate_edge_features {

    my $graph = shift;
    my $instance = shift;
    my $graph_edge = shift;
    my $feature_definitions = shift;

    my %feature_values;
	
    foreach my $edge_feature (@{ $feature_definitions }) {
	
	my $feature_id = _feature_2_id( $graph_edge , $edge_feature );
	my $feature_value = _generate_feature( $graph , $instance , $graph_edge , $feature_id );
	
	if ( $feature_value ) {
	    $feature_values{ $feature_id } = $feature_value;
	}
	
    }

    return \%feature_values;

}

sub _generate_feature {

    my $graph = shift;
    my $training_sample = shift;
    my $graph_edge = shift;
    my $feature_id = shift;

    my ( $from_vertex , $to_vertex ) = @{ $graph_edge };

    if ( $graph->get_vertex_attribute( $from_vertex , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	$from_vertex = decode_json( $graph->get_vertex_attribute( $from_vertex , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) )->{ $training_sample->url() };
    }
    if ( $graph->get_vertex_attribute( $to_vertex , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	$to_vertex = decode_json( $graph->get_vertex_attribute( $to_vertex , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) )->{ $training_sample->url() };
    }

    my $feature_value = undef;

    # TODO: different behavior for slot locations ?

    if ( ! defined( $from_vertex ) || ! defined( $to_vertex ) ) {

	# One of the nodes for the current edge is not relevant
	# Force feature value to 0
	$feature_value = 0;

    }
    # TODO: move this to individual classes
    elsif ( $feature_id == _feature_2_id( $graph_edge , $Web::Summarizer::Graph2::Definitions::FEATURE_EDGE_TARGET_FREQUENCY ) ) {

	# target edge frequency
	$feature_value = _edge_frequency( $training_sample->get_field('content.phrases') , $from_vertex , $to_vertex );

    }
    elsif ( $feature_id == _feature_2_id( $graph_edge , $Web::Summarizer::Graph2::Definitions::FEATURE_SOURCE_TARGET_FREQUENCY ) || $feature_id == _feature_2_id( $graph_edge , $Web::Summarizer::Graph2::Definitions::FEATURE_SINK_TARGET_FREQUENCY ) ) {

        # adjusted node priors

	my $node = undef;
	
	if ( $feature_id == _feature_2_id( $graph_edge , $Web::Summarizer::Graph2::Definitions::FEATURE_SOURCE_TARGET_FREQUENCY ) ) {
	    $node = $from_vertex;
	}
	elsif ( $feature_id == _feature_2_id( $graph_edge , $Web::Summarizer::Graph2::Definitions::FEATURE_SINK_TARGET_FREQUENCY ) ) {
	    $node = $to_vertex;
	}
	else {
	    # not handled
	}

	if ( defined( $node ) ) {

	    #my $node_prior = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_PRIOR );
	    #my $node_frequency_in_target = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_TARGET_FREQUENCY );
	    #my $node_frequency_expected = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_EXPECTED_FREQUENCY );
	    #$feature_value = _adjusted_feature_value( $node_prior , $node_frequency_in_target , $node_frequency_expected );

	    # node frequency
	    $feature_value = _node_frequency( $training_sample->get_field('content.phrases') , $node );

	}

    }
    else {

	# n-gram features
	
	my $content = $training_sample->get_field( 'content.phrases' );
	my $feature = $id2feature{ $feature_id };
	$feature_value = 0;
	while ( $content =~ m/$feature/sig ) {
	    $feature_value++;
	}

    }

    if ( ! defined( $feature_value ) ) {
	die "Feature not supported: $feature_id";
    }

    return $feature_value;

}	

sub _edge_frequency {

    my $content = shift;
    my $token1 = shift;
    my $token2 = shift;

    my $count1 = _node_frequency( $content , $token1 );
    my $count2 = _node_frequency( $content , $token2 );

    return ( $count1 * $count2 );

}

sub _node_frequency {

    my $content = shift;
    my $token = shift;

    my $count = 0;
    
    while ( $content =~ m/$token/sgi ) {
	$count++;
    } 

    return $count;

}

sub _compatible_slot {

    my $slot_node = shift;
    my $unigram = shift;

    # 1 - determine type of unigram
    # TODO

    # if ( $type eq ...

    return 0

}

sub _unigrams {

    my $text_data = shift;

    my $tokens = _generate_sequence( $text_data );
    my %token2counts;
    map { $token2counts{ $_ }++; } @{ $tokens };

    return \%token2counts;

}

sub _extract_paths {

    my $text_data = shift;

    my @paths;
    while ( $text_data =~ m/((?:[A-Z])(?:\w+){5,}\.)(?:\W)/sg ) {
	push @paths, _generate_sequence( $1 );
    }

    return \@paths;

}

# Not useful ?
sub _insert_slot {

    my $graph = shift;
    my $key = shift;
    my $paths = shift;

    # 1 - insert node
    my $slot_node = _insert_node( $graph , "[[slot||$key]]" , "slot" , {} );

    return $slot_node;

}

sub _insert_reference_content {

    my $graph = shift;
    my $stats = shift;
    my $url = shift;
    my $content = shift;

    # 1 - insert reference paths
    # TODO

    # 2 - insert reference fragments
    # TODO

}

sub _insert_path {

    my $graph = shift;
    my $url = shift;
    my $sequence = shift;

    my %path_status;

    # Just as \cite{Filippova} we allow for cycles --> linear similarity not sufficient w/in category
    # 1 - align unambiguous terms (single occurrence in graph and path)
    my @mapped_sequence = map { _insert_node( $graph , $_, $url , \%path_status , [] ); } grep { defined( $_ ); } @{ $sequence };

    # 3 - stop words mapped only if overlap in neighbors --> convert to a top 50% word rule ? might make sense w/in categories
    # TODO ?

    # Once all the nodes have been aligned/inserted, we add/update edges (see \cite{Filippova2010}
    {
	my $previous_node = undef;
	foreach my $aligned_node (@mapped_sequence) {
	    
	    if ( defined( $previous_node ) ) { 
		_insert_edge( $graph , $url , $previous_node , $aligned_node );
	    }

	    $previous_node = $aligned_node;

	}
    }
    
    # update global stats
    $graph->set_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT , ( $graph->get_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT ) || 0 ) + 1 );

    return \@mapped_sequence;
    
}

sub _insert_node {

    # Graph being updated
    my $graph = shift;
    
    # Surface form of the node to add
    my $surface_data = shift;
    my $surface = $surface_data;
    my $data = undef;
    if ( ref( $surface_data ) ) {
	$surface = $surface_data->[ 0 ]->[ 0 ];
	$data = $surface_data;
    }

    # Id for the current gist
    my $label = shift;

    # Nodes that already appear in the current gist (should we maintain this as a sequence ?)
    my $nodes_status = shift;

    # The only things that prevents use from reusing an existing node is its expected context
    # TODO: select existing node with the most compatible context
    my $filter = shift;
    
    my $create_new = 1;
    my $node = $surface;
    my $node_map = decode_json( $graph->get_graph_attribute( 'node_map' ) );
    
    # If no node exist for this surface form, we can create it
    if ( ! defined( $node_map->{ $surface } ) ) {
	$node_map->{ $surface } = [];
	$create_new = 1;
    }
    else {
	
	# need to decide if one of the existing nodes can be used as a host
	
	my $best_candidate = undef;
	my $best_candidate_score = -1;
	
	foreach my $candidate_node (@{ $node_map->{ $surface } }) {
	    
	    if ( defined( $nodes_status->{ $candidate_node } ) ) {
		# This node already appears in the current path
		next;
	    }
	    
	    # Default so that a candidate is found only if there is some level of filter match overall
	    # TO CHECK !
	    my $candidate_score = 0;
	    
	    my @candidate_neighbors = $graph->neighbors( $candidate_node );
	    foreach my $candidate_neighbor (@candidate_neighbors) {
		
		foreach my $filter_node (@{ $filter }) {
		    
		    if ( $candidate_neighbor->get_vertex_attribute( $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_VERBALIZATION ) eq $filter_node ) {
			$candidate_score++;
		    }
		    
		}
		
	    }
	    
	    if ( $candidate_score > $best_candidate_score ) {
		$best_candidate = $candidate_node;
		$best_candidate_score = $candidate_score;
	    }
	    
	}
	
	if ( defined( $best_candidate ) ) {
	    $node = $best_candidate;
	    $create_new = 0;
	}
	
    }
    
    # Create a new node if required
    if ( $create_new ) {
	my $current_count = scalar( @{ $node_map->{ $surface } } );
	if ( $current_count ) {
	    $node = join( "/" , $surface , $current_count );
	}
	push @{ $node_map->{ $surface } } , $node;
    }
    
    # Actually create underlying vertex
    if ( ! $graph->has_vertex( $node ) ) {
	
	$graph->add_vertex( $node );
	
	# set vertex verbalization (label)
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_VERBALIZATION , $surface );	
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA, encode_json( {} ) );
	
    }
    
    # TODO: this is a good place to update the vertex importance ?
    $graph->set_vertex_weight( $node , ( $graph->get_vertex_weight( $node ) || 0 ) + 1 );
    
    if ( defined ( $data ) ) {
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 1 );
	my $current_data = decode_json( $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) );
	$current_data->{ $data->[ 3 ] } = $data->[ 4 ];
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA , encode_json( $current_data ) );
    }
    else {
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 0 );
    }
    
    # Register this node for the current gist
    $nodes_status->{ $node } = 1;
    
    # Update node map
    $graph->set_graph_attribute( 'node_map' , encode_json( $node_map ) );
    
    return $node;
    
}

sub _insert_edge {

    my $graph = shift;
    my $url = shift;
    my $from_node = shift;
    my $to_node = shift;

    if ( ! defined( $from_node ) || ! defined( $to_node ) ) {
	die "We have a problem, invalid from/to node ...";
    }
    
    if ( ! $graph->has_edge( $from_node , $to_node ) ) {
	$graph->add_edge( $from_node , $to_node );
	$graph->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , 1 );
    }
    else {
	$graph->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , $graph->get_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) + 1 );
    }
    
}

# This needs to be shared by all systems
sub normalize_string {

    my $string = shift;

    $string =~ s/[[:punct:]]+//sig;
    $string = lc( $string );

    return $string;

}

sub _generate_sequence {

    my $string = shift;
    
    my @tokens = grep { length( $_ ); } split / |\p{Punct}/, $string;

    # add BOG/EOG nodes to sequence
    my @full_sequence = ( $Web::Summarizer::Graph2::Definitions::NODE_BOG , @tokens , $Web::Summarizer::Graph2::Definitions::NODE_EOG );
    
    return \@full_sequence;

}

sub _get_filtered_phrases {

    my $string = shift;
    my $threshold = shift || 0;

    my %tokens2count;
    map{ $tokens2count{ normalize_string( $_ ) }++; } @{ _generate_sequence( $string ) };

    return grep { length( $_ ) && ( $tokens2count{ $_ } > $threshold ) } keys( %tokens2count );

}

sub _check_path {

    my $graph = shift;
    my $sequence = shift;
    my $url = shift;

    # Confirm that the nodes in the generated path are effectively tied to the current path
    foreach my $node (@{ $sequence }) {
	
	if ( $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	    
	    my $node_data = decode_json( $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) );
	    if ( ! defined( $node_data->{ $url } ) ) {
		die "We have a problem - no target data associated with node $node for URL $url ...";
	    }
	    
	}
	
    }

    return 1;

}

=pod
my $field_anchortext_basic = 'anchortext.basic';
my $anchortext_basic = $entry->get_field( $field_anchortext_basic );
map {
    $entry_all_candidate_phrases{ $_ }++;
    $entry_frequencies{ $field_anchortext_basic }{ $_ }++;
} _get_filtered_phrases( $anchortext_basic );

my $field_anchortext_sentence = 'anchortext.sentence';
my $anchortext_sentence = $entry->get_field( $field_anchortext_sentence );
map {
    $entry_all_candidate_phrases{ $_ }++;
    $entry_frequencies{ $field_anchortext_sentence }{ $_ }++;
} _get_filtered_phrases( $anchortext_sentence );

my $title = $entry->get_field( 'title' );
map { $entry_all_candidate_phrases{ $_ }++; } _get_filtered_phrases( $title );

my $url_words = $entry->get_field( 'url.words' );
map { $entry_all_candidate_phrases{ $_ }++; } _get_filtered_phrases( $url_words );

# Mode-dependent filtering
if ( defined($mode) && $mode eq $MODE_SALIENT ) {
    
    # We only consider terms that are in the top N of salient terms for this URL
    #my $saliency_cutoff = 20;
    #my $saliency_cutoff = 1000000;
    my $saliency_cutoff = 100;
    
    @candidate_phrases = sort { _saliency( $b , \%entry_frequencies ) <=> _saliency( $a , \%entry_frequencies ) }
    grep { ( $frequencies{ 'summary' }{ $_ } || 0 ) < 0.25; }
    grep { ( $frequencies{ 'content.phrases' }{ $_ } || 0 ) < 0.1; }
    keys( %entry_all_candidate_phrases );
    
    if ( scalar(@candidate_phrases) > $saliency_cutoff ) {
	splice @candidate_phrases, $saliency_cutoff;
    }
    
}
else {
    
    # By default we consider all terms available for this entry (highly skewed distribution !)
    @candidate_phrases = keys( %entry_all_candidate_phrases );
    
}

foreach my $phrase (@candidate_phrases) {
    
    if ( defined( $minimum_importance ) || defined ( $maximum_importance ) ) {
	# we only focus on terms that appear anywhere between $minimum_importance and $maximum_importance in the reference gists
	if ( 
	    ( ! defined( $importances{ 'summary' }{ $phrase } ) ) ||
	    ( $importances{ 'summary' }{ $phrase } < ( $minimum_importance || 0 ) ) || ( $importances{ 'summary' }{ $phrase } > ( $maximum_importance || 1 ) )
	    ) {
	    next;
	}
    }
    
    if ( defined( $term ) && ( $phrase ne $term ) ) {
	next;
    }
    
    my %phrase_features;
    
    # TODO: push this to the outer loop
    my @combinable;
    
    # Ground Truth
    my $ground_truth = ( $summary_phrase2appearance{ $phrase } ? 1 : 0 );
    
    # Appears in content ?
    my $feature_appears_in_content = 'appears_in_content::binary';
    _update_entry_features( \%phrase_features , $feature_appears_in_content, ( $content_phrase2appearance{ $phrase } || 0 ));
    #_update_entry_features( \%phrase_features , join("::", $feature_appears_in_content, 'numeric'), ( $content_phrase2appearance{ $phrase } || 0 ));
    push @combinable, $feature_appears_in_content;
    
    # Appears in anchortext basic ?
    my $feature_appears_in_anchortext_basic = 'appears_in_anchortext_basic::binary';
    _update_entry_features( \%phrase_features , $feature_appears_in_anchortext_basic, _n_match( $anchortext_basic , $phrase ));
    #_update_entry_features( \%phrase_features , join("::", $feature_appears_in_anchortext_basic, 'numeric'), _n_match( $anchortext_basic , $phrase ));
    push @combinable, $feature_appears_in_anchortext_basic;
    
    # Appears in anchortext sentence ?
    my $feature_appears_in_anchortext_sentence = 'appears_in_anchortext_sentence::binary';
    _update_entry_features( \%phrase_features , $feature_appears_in_anchortext_sentence , _n_match( $anchortext_sentence , $phrase ));
    #_update_entry_features( \%phrase_features , join("::", $feature_appears_in_anchortext_sentence, 'numeric'), _n_match( $anchortext_sentence , $phrase ));
    push @combinable, $feature_appears_in_anchortext_sentence;
    
    # Appears in title ?
    my $feature_appears_in_title = 'appears_in_title::binary';
    _update_entry_features( \%phrase_features , $feature_appears_in_title , _n_match( $title , $phrase ));
    push @combinable, $feature_appears_in_title;

    # TODO: this is super slow right now !
    # Appears in h1 / h2 section ? in outgoing link ?
    foreach my $target_section ('h1','h2','a') {
	my $feature_appears_in_section_XX = "appears_in_section_${target_section}::numerical";
	_update_entry_features( \%phrase_features , $feature_appears_in_section_XX , _appears_in_context( $url_content , $phrase , $target_section ));
	# TODO: combine ?
    }
    
    # Appears in URL words ?
    my $feature_appears_in_url_words = 'appears_in_url_words::binary';
    _update_entry_features( \%phrase_features , $feature_appears_in_url_words, _n_match( $url_words , $phrase ));
    push @combinable, $feature_appears_in_url_words;
    
    # Relative position - Content ?
    my $feature_relative_position_content = 'relative_position_content::numeric';
    _update_entry_features( \%phrase_features , $feature_relative_position_content, _relative_position( $content_phrases , $phrase ));
    push @combinable, $feature_relative_position_content;
    
    # TODO: improve with better dictionary ?
    # Primary POS
    my $feature_primary_pos = 'primary_pos';
    _update_entry_features( \%phrase_features , join("::", $feature_primary_pos, 'class'), _get_primary_pos( $phrase ));
    
    # TODO: do we have to filter out meta-description (they're not being rendered anyways) ?
    
    # ****************** category features ****************************
    # More relevant if we consider models at the super-category level ?
    
    # Importance in category gists
	    my $feature_genericity_in_category_gists = 'genericity_in_category_gists::numeric';
	    _update_entry_features( \%phrase_features , $feature_genericity_in_category_gists, ( $global{ 'summary' }{ $phrase } || 0 ));
	    push @combinable, $feature_genericity_in_category_gists;
	    
	    # Importance in category contents
	    my $feature_genericity_in_category_contents = 'genericity_in_category_contents::numeric';
	    _update_entry_features( \%phrase_features , $feature_genericity_in_category_contents, ( $global{ 'content.phrases' }{ $phrase } || 0 ));
	    push @combinable, $feature_genericity_in_category_contents;

	    # Importance in anchortext (sentence)
	    my $feature_genericity_in_anchortext_sentence = 'genericity_in_anchortext_sentence::numeric';
	    _update_entry_features( \%phrase_features , $feature_genericity_in_anchortext_sentence, ( $global{ 'anchortext.sentence' }{ $phrase } || 0 ));
	    push @combinable, $feature_genericity_in_anchortext_sentence;

	    # Is this phrase more important in gists than in contents ?
	    my $feature_importance_gists_vs_contents = 'importance_gists_vs_contents::numeric';
	    _update_entry_features( \%phrase_features , $feature_importance_gists_vs_contents, ( ($importances{ 'summary' }{ $phrase } || 0) > ( $importances{ 'content.phrases' }{ $phrase } || 0 ) ? 1 : 0 ));
	    push @combinable, $feature_importance_gists_vs_contents;

	    # Is this phrase more important in contents than in gists ?
	    my $feature_importance_contents_vs_gists = 'importance_contents_vs_gists::numeric';
	    _update_entry_features( \%phrase_features , $feature_importance_contents_vs_gists, ( ($importances{ 'summary' }{ $phrase } || 0) < ( $importances{ 'content.phrases' }{ $phrase } || 0 ) ? 1 : 0 ));
	    push @combinable, $feature_importance_contents_vs_gists;

#	    # Importance ratio in gists vs contents
#	    my $feature_importance_gists_vs_contents_ratio = 'importance_gists_vs_contents_ratio::numeric';
#	    _update_entry_features( \%phrase_features , $feature_importance_gists_vs_contents_ratio , ($importances{ 'summary' }{ $phrase } || 0) / ( ( $importances{ 'content.phrases' }{ $phrase } || 0 ) + 0.0000001 ));
#	    push @combinable, $feature_importance_gists_vs_contents_ratio;

	    # ****************** category features ****************************

	    foreach my $feature_spec (@feature_specs) {
		
		# load features
		my $current_features = $entry->get_field( $feature_spec->[0] , $feature_spec->[2] );
		
		# feature filtering ?
		# TODO, but has to be based on global counts
		# append feature values
		foreach my $feature (keys(%{ $current_features })) {
		    _update_entry_features( \%phrase_features , join("::", join("**", $phrase, $feature), $feature_spec->[1]), $current_features->{ $feature });
		    #_update_entry_features( \%phrase_features , $feature, $feature_spec->[1], $current_features->{ $feature });
		}
		
	    }
	    
	    # combined features
	    for (my $i=0; $i<scalar(@combinable); $i++) {

		my $feature1 = $combinable[ $i ];

		for (my $j=0; $j<$i; $j++) {

		    my $feature2 = $combinable[ $j ];
		    
		    if ( $DEBUG && ( $feature1 eq $feature2 ) ) {
			die "Combining identical features: $feature1 / $feature2";
		    }

		    my $combined_value = ( $phrase_features{ $feature1 } || 0 ) * ( $phrase_features{ $feature2 } || 0 );

		    _update_entry_features( \%phrase_features , join("::", join("**", "combined", $feature1, $feature2), 'numeric'), $combined_value );

		}

	    }

	    print OUTPUT_FILE join("\t", $url, $phrase, $ground_truth, map{ $features2index{ $_ } . ":" . $phrase_features{ $_ }; } keys(%phrase_features)) . "\n";
	    
	}

    }

    close OUTPUT_FILE;

}

sub _appears_in_context {

    my $data = shift;
    my $token = shift;
    my $context = shift;

    my $count = 0;

    while ( $data =~ m|<${context}[^>]*>(?:(?!:</${context}>).)*${token}|sig ) {
	$count++;
    }

    return $count;

}

sub _relative_position {

    my $data = shift;
    my $token = shift;

    my $relative_position = 1;

    if ( $data =~ m/$token/sig ) {
	$relative_position = $-[0] / length($data);
    }

    return $relative_position;

}

sub _n_match {

    my $data = shift;
    my $token = shift;

    my $n_matches = 0;

    while ( $data =~ m/\Q$token\E/sig ) {
	$n_matches++;
    }

    return $n_matches;

}

my %pos_cache;
sub _get_primary_pos {

    my $word = shift;
    
    if ( ! defined( $pos_cache{ $word } ) ) {
	
	my @all_pos = $wn->querySense( $word );

	my $primary_pos = 'unknown';
	if ( scalar(@all_pos) ) {
	    $primary_pos = (split /\#/, $all_pos[0])[1];
	}

	$pos_cache{ $word } = $primary_pos;

    }

    return $pos_cache{ $word };

}

sub _abstraction_type {

    my $word = shift;
    my $unique_appearances = shift;
    my $fields = shift;
    my $reference_count = shift;

    my $is_in_summary = 0;
    my $is_in_other_fields = 0;

    foreach my $field (@{ $fields }) {

	my $count = $unique_appearances{ $field }{ $word } || 0;

	if ( $field eq 'summary' ) {
	    $is_in_summary = $count;
	}
	else {
	    $is_in_other_fields += $count;
	}

    }

    my $abstraction_type = undef;

    if ( $is_in_summary && !$is_in_other_fields ) {

	if ( $is_in_summary / $reference_count > 0.9 ) {
	    # Generic term / Punctuation
	    $abstraction_type = "generic";
	}
	if ( $is_in_summary / $reference_count > 0.2 ) {
	    # Term that is a true abstraction of concepts
	    $abstraction_type = "abstract";
	}
	else {
	    # Term that is target specific but implied by the target URL.
	    # e.g. a city might imply a country
	    $abstraction_type = "abstract-unique";
	}

    }
    
    else {

	# ?
	$abstraction_type = "regular";

    }

    return $abstraction_type;

}

# compute saliency of a given term
sub _saliency {

    my $term = shift;
    my $entry_frequencies = shift;

    my $term_combined_idf = 0.2 * ( $idfs{ 'content.phrases' }{ $term } || 0 ) + 0.8 * ( $idfs{ 'anchortext.sentence' }{ $term } || 0 );
    my $term_combined_df = 0.2 * ( $entry_frequencies->{ 'content.phrase' } || 0 ) + 0.8 * ( $entry_frequencies->{ 'anchortext.sentence' }{ $term } || 0 );
    my $saliency = $term_combined_df * $term_combined_idf;

    return $saliency;

}

=cut

1;
