package GistGraph::AppearanceModel::MajorityVote;

# Base class for all majority-vote type of appearance models

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use GistGraph;
use GistGraph::AppearanceModel;

extends 'GistGraph::AppearanceModel';

with Storage('format' => 'JSON', 'io' => 'File');

# TODO: do we still need this class ?

no Moose;

1;
