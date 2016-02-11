package Modality::TitleModality;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Modality::SingleStringSequenceModality' );

sub _sequence_class_builder {
    return 'Web::Summarizer::StringSequence';
}

sub data_generator {
    my $this = shift;
    # TODO : share this among modalities ?
    my $metadata = Service::Web::Analyzer->metadata( $this->object->_html_document->raw_data );
    my $title = $metadata->{ 'title' };
    return [ $title ];
}

with( 'Modality' => { fluent => 1 , namespace => 'web' , id => 'title' } );

__PACKAGE__->meta->make_immutable;

1;
