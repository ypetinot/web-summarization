package GistGraph::AppearanceModel::Independent;

# Base class for non-correlated Appearance Models

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'GistGraph::AppearanceModel';

# Fields

# each node (id) maps to an individual appearance model
has 'classifiers' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# train model
sub _train {

    my $this = shift;
    my $instances = shift;
    my $full_ground_truths = shift;

    # Note: feature set could be saved across models as a means to avoid unnecessary computations
    my $feature_set = undef;
    my $training_documents_features = undef; 

    # generate a binary classifier for every single node in the gist graph
    my @node_ids = @{ $this->gist_graph()->sorted_nodes(1) };
    foreach my $node_id (@node_ids) {

	print STDERR "[Independent] Training model for node: $node_id\n";

	my $node = $this->gist_graph()->nodes()->{ $node_id };
	my $node_instances = $instances;

	# determine ground truth for this node
	my @node_ground_truth;
	my $positive_count = 0;
	my $negative_count = 0;
	foreach my $full_ground_truth (@{ $full_ground_truths }) {
	    my @matches = grep { $_ eq $node_id } @{ $full_ground_truth };
	    if ( scalar(@matches) ) {
		$positive_count += 1;
		push @node_ground_truth, 1;
	    }
	    else {
		$negative_count += 1;
		push @node_ground_truth, 0;
	    }
	}

	# rebalance training set if required
	# Note: keep this here for now since this is the only class that has knowledge of Joint vs Independent learning
	# TODO: ideally, move this to NPModel::Base
	if ( ( $positive_count != $negative_count ) && ( $this->parameters()->{ 'balanced' } ) ) {

	    my $to_remove = 0;
	    my $excess = abs( $positive_count - $negative_count );
	    if ( $positive_count > $negative_count ) {
		$to_remove = 1;
	    }
	    print STDERR "$positive_count / $negative_count - Will attempt to remove $excess ($to_remove)-instances to balance training data for node $node_id ...\n";

	    my @adjusted_node_instances;
	    my @adjusted_node_ground_truth;
	    for (my $i=0; $i<scalar(@node_ground_truth); $i++) {
		
		if ( $node_ground_truth[ $i ] == $to_remove ) {
		    if ( $excess ) {
			$excess--;
			next;
		    }
		}
		
		push @adjusted_node_instances, $instances->[ $i ];
		push @adjusted_node_ground_truth, $node_ground_truth[ $i ];

	    } 

	    $node_instances = \@adjusted_node_instances;
	    @node_ground_truth = @adjusted_node_ground_truth;
	    
	}

	if ( ! scalar( @{$node_instances} ) ) {
	    print STDERR "No instances available to train independent model for node $node_id ...\n";
	}

	if ( scalar(@node_ground_truth) != scalar(@{$node_instances}) ) {
	    die "Mismatch between ground truth and instances ...\n";
	}

	# individual models should be instances of NPModel::Base
	my $independent_model = ( $this->parameters()->{ 'learner' } )->new( 
	    base_directory => $this->get_support_directory(),
	    bin_root => $FindBin::Bin,
	    contents => $node_instances,
	    description => join("::",$this->parameters()->{ 'learner' },$this->key(),$node_id),
	    features => $this->parameters()->{ 'features' }
	    );
	$independent_model->initialize( $feature_set );
	$independent_model->train( \@node_ground_truth );
	$independent_model->finalize();

	if ( ! defined($feature_set) ) {
	    $feature_set = $independent_model->get_feature_set();
	}

	$this->classifiers()->{ $node_id } = $independent_model;

	print STDERR "\n";

    }

}

# run inference
sub _run_inference {

    my $this = shift;
    my $url_data = shift;
    
    # run classification for each independent model
    foreach my $node_id ( keys( %{ $this->classifiers() } ) ) {

	my $node_appearance = $this->classifiers()->{ $node_id }->classify( $url_data );
	
	# finally update appearance field
	$this->appearance()->{ $node_id } = $node_appearance;

    }

}

__PACKAGE__->meta->make_immutable;

1;
