package WordGraph::ReferenceRanker::ReferenceTargetJointProbability;

# Note : purpose of the model is to boost/reinforce object-summary fitness model
# CURRENT : relationship to Kernel methods ? Could this be a Kernel-based approach for structured data and/or complex objects ?

use strict;
use warnings;

use Web::Summarizer::Sequence::Featurizer;
use Web::UrlData::Featurizer::ModalityFeaturizer;

use Moose;
use namespace::autoclean;

extends 'WordGraph::ReferenceRanker::ObjectObjectSummaryRanker';

__PACKAGE__->meta->make_immutable;

1;
