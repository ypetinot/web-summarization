package Modality::PageModality;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Modality::MultiStringSequenceModality' );

sub _sequence_class_builder {
    return 'Web::Summarizer::StringSequence';
}

sub data_generator {
    my $this = shift;
    return $this->object->_html_document->segment;
}

with ( 'Modality' => {  fluent => 1 , namespace => 'web' , id => 'content' } );

__PACKAGE__->meta->make_immutable;

1;
