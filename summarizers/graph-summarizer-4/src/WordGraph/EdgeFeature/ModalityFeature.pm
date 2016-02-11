package WordGraph::EdgeFeature::ModalityFeature;

use Moose;

extends 'WordGraph::EdgeFeature';

# target modality
has 'modality' => ( is => 'ro' , required => 1 );

# feature key
sub key {

    my $this = shift;
    my $domain = shift;

    return $this->SUPER::key( $domain , $this->modality() , @_ );

}

no Moose;

1;
