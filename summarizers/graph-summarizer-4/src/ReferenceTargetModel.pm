package ReferenceTargetModel;

# Base class for all models that leverage an input object, together with one ore more reference objects (pairs) to generate a new output object (target)
# Note : the reference set can be (theoretically) extended to the entire reference corpus and should therefore be thought of as such.

# Note : possible feature sets
# 1 - one set of features for each reference object , akin to a (soft) NN model ==> do not require a Factor Graph formulation, simply generate the features and learn (easy) but learning limited to single instance unless we use the full training set as reference (future work ?)
# 2 - single set of features ?

# TODO : create Model:: namespace ?

use strict;
use warnings;

use ReferenceTargetInstance;

use Moose::Role;

with('Model');

# TODO : to be removed ?
=pod
# object modalities
# TODO : should the set of modalities be configurable ?
has 'object_modalities' => ( is => 'ro' , isa => 'ArrayRef[Modality]' , init_arg => undef , lazy => 1 , builder => '_object_modalities_builder' );
sub _object_modalities_builder {
    my $this = shift;
    #return $this->target_object->modalities_ngrams();
    return Category::UrlData->modalities_ngrams;
}
=cut

1;
