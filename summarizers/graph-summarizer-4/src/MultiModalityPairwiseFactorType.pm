package MultiModalityPairwiseFactorType;

use strict;
use warnings;

# base class for all (energy-based) (unnormalized) multi-modality pairwise potentials

use Moose::Role;
use namespace::autoclean;

with('PairwiseFactorType');

# object modalities
# TODO : this might have to be moved to a sub-class as I'm introducing different types (e.g. trainable) of object-object potentials
has 'modalities' => ( is => 'ro' , isa => 'ArrayRef[Modality::NgrammableModality]' , required => 1 );

1;
