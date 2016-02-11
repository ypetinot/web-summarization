package WordGraph::ReferenceRanker::IterativeSimilarity;

use strict;
use warnings;

use Moose;

extends 'WordGraph::ReferenceRanker';

# base reference ranking (to determine initial candidate)
has 'base_ranking' => ( is => 'ro' , isa => 'WordGraph::Reference ...

no Moose;

1;
