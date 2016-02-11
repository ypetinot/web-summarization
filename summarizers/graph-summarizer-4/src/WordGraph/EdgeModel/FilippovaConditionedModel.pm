package WordGraph::EdgeModel::FilippovaConditionedModel;

use Moose;
use namespace::autoclean;

extends 'WordGraph::EdgeModel::FilippovaImprovedModel';

sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $edge_features = shift; # needed ?
    my $instance = shift;

    # 1 - get original cost ( this can be thought of as a corpus
    my $original_filippova_improved_cost = $this->SUPER::_compute( $graph , $edge , $edge_features , $instance );

    # 2 - incorporate conditional factor
    my $condition_factor = ( 1 / ( ( $edge_features->{ 'source::frequency::content.rendered' } || 0.0001 ) ) ) * ( 1 / ( $edge_features->{ 'sink::frequency::content.rendered' } || 0.0001 ) );
    my $conditioned_cost = $condition_factor * $original_filippova_improved_cost;

    return $conditioned_cost;

}

__PACKAGE__->meta->make_immutable;

1;
