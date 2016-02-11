package ObjectSummaryEnergyModel;

# Note/TODO : this is not in use anymore but I will have to come back to the goal of training an energy-based machine to learn the mapping between an object and its summary.

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : this is not good at all ...
sub compute_energy {

    my $this = shift;
    my $object = shift;
    my $summary = shift;
    
    my $object_elements = $this->_build_object_data_elements( $object );
    # TODO: can we do better than this ?
    my $summary_string = "$summary";
	    
    my $reference_entry_score = 0;

    # 2 - evaluate relevance of the reference summary given set of descriptive elements for the target object
    foreach my $object_element (keys( %{ $object_elements } )) {
				
	my $object_element_weight = scalar( keys( %{ $object_elements->{ $object_element } } ) );
				
	if ( $summary_string =~ m/\Q$object_element\E/sgi ) {
	    # Note : should we multiply instead ?
	    $reference_entry_score += $object_element_weight;
	}
	
    }

    # normalize by summary length
###    my $reference_entry_score_normalized = $reference_entry_score / ( length( $summary_string ) + 1 );

    return $reference_entry_score;

}

=pod
# --> reenable if caching needed
###has '_target_data_elements' => ( is => 'rw' , isa => 'HashRef' , builder => '_build_target_data_elements' , lazy => 1 );

sub _build_object_data_elements {

    my $this = shift;
    my $object = shift;

    # 1 - get all words (bigrams, trigrams ?) appearing in at least two modalities of the target url
    # TODO : use a global data extractor ?
    my $reference_elements = $object->collect_instance_descriptive_content( $object );

    return $reference_elements

}
=cut

__PACKAGE__->meta->make_immutable;

1;
