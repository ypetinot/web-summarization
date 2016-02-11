package Modality::AnchortextModality;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Modality::MultiStringSequenceModality' );

sub _sequence_class_builder {
    return 'Web::Summarizer::StringSequence';
}

# anchortext
has '_anchortext' => ( is => 'ro' , isa => 'Web::Anchortext' , init_arg => undef , lazy => 1 , builder => '_anchortext_builder' );
sub _anchortext_builder {
    my $this = shift;
    my $anchortext = new Web::Anchortext( url => $this->object->url );
    return $anchortext;
}

sub data_generator {
    my $this = shift;
    # TODO : need to increase and ultimately remove max parameter
    # TODO : turn max_per_host into a configurable parameter
    return $this->_anchortext->segment( max => 20 , max_per_host => 10 ) ;
}

with ( 'Modality' => { fluent => 1 , namespace => 'web' , id => 'anchortext' } );

__PACKAGE__->meta->make_immutable;

1;
