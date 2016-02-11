package GraphSummary;

use JSON;

use Moose;

extends 'Category::Data';

# fields
has 'model' => (
    is => 'rw',
    isa => 'GraphModel',
    clearer => 'clear_model',
    );

has 'node_states' => (is => 'rw', isa => 'HashRef');
has 'url' => (is => 'ro', isa => 'Str');
has 'gist' => (is => 'rw', isa => 'Str');

sub BUILD {

    my $this = shift;
    my $args = shift;

=pod
    my $json_string = $args->{'data'};
    my $json_object = from_json($json_string);
    $this->node_states( $json_object->{'node_stats'} );
=cut

}

# get active nodes
sub get_active_nodes {

    my $this = shift;

    my $states = $this->node_states();
    my @active_nodes = map { $this->model()->get_node( $_ ); } keys( %{$states} );

    return \@active_nodes;

}

# method to set the state for a particular node
sub set_state {

    my $this = shift;
    my $node_id = shift;
    my $evidence = shift;
    my $value = shift;

    # retrieve node for the target node id
    my $target_node = $this->model()->get_node($node_id);
    my $target_id = $target_node->get_id();
    
    # store state
    $this->{'node_states'}->{$target_id} = [ $evidence , $value ];
    
}

# method to get the state for a particular node
sub get_state {

    my $this = shift;
    my $node_id = shift;

    # retrieve node for the target node it
    my $target_node = $this->model()->get_node($node_id);
    my $target_id = $target_node->get_id();

    # TODO: make this a class ?
    my $state = $this->{'node_states'}->{$target_id};
    
    return $state;

}

# method to get the evidence for a particular node
sub get_evidence {

    my $this = shift;
    my $node_id = shift;

    my $result = 0;

    # retrieve node for the target node_id
    my $target_node = $this->model()->get_node($node_id);

    if ( ! $target_node ) {
	return 0;
    }

    my $target_id = $target_node->get_id();
    my $state = $this->get_state($target_id);
    if ( defined($state) ) {
	$result = $state->[0];
    }

    return $result;

}

# pre-serialization preparation
# TODO: can we implement this more elegantly with Moose ?
sub pre_serialize {

    my $this = shift;

    # remove reference to model
    $this->clear_model;

}

no Moose;

1;
