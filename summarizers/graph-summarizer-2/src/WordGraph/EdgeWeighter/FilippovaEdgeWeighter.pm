package WordGraph::EdgeWeighter::FilippovaEdgeWeighter;

use Moose;

extends 'WordGraph::EdgeWeighter';

# compute weights
sub compute_weights {
    
    my $this = shift;
    my $params = shift;

    # What are the keys ?
    my %w;

    # 1 - simple shortest path formulation (Section 2.2 in Filippova et al., 2010)
    # edge weights obtained by inverting the weight of individual edges

    # Static weights ? --> no, we just focus on one specific features, all other weights being forced to 0

    return \%w;

}

no Moose;

1;
