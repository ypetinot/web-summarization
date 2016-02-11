package NPModel::BinaryClassifier::Single;

use Moose;

use NPModel::BinaryClassifier;

extends 'NPModel::BinaryClassifier';

sub _train {

    my $this = shift;
    my $training_set = shift;
    my $ground_truths = shift;

    

}

sub classify {

}

no Moose;

1;
