package Web::Extractor::SentenceExtractor;

use strict;
use warnings;

use Web::Summarizer::SentenceBuilder;

use Moose::Role;

# minimum (sentence) length
has 'min_length' => ( is => 'ro' , isa => 'Num' , default => 5 );

# TODO : is there any way to avoid creating a "custom" SentenceBuilder here ? Required because of format discrepancies in sentence representation/storage
# extractor sentence builder
has '_extractor_sentence_builder' => ( is => 'ro' , isa => 'Web::Summarizer::SentenceBuilder' , builder => '_extractor_sentence_builder_builder' );
sub _extractor_sentence_builder_builder {
    my $this = shift;
    return new Web::Summarizer::SentenceBuilder;
}

# TODO : add filtering using a custom callback function
sub filter_extracted_sentence {

    my $this = shift;
    my $sentence = shift;

    # filter based on sentence length
    if ( $sentence->length < $this->min_length ) {
	return 0;
    }

    return 1;

}

around 'extract_sentences' => sub {

    my $orig = shift;
    my $self = shift;

    my $instance = $_[ 0 ];

    my $sentences_raw_unfiltered = $self->$orig( @_ );
    my @sentences_filtered = grep { $self->filter_extracted_sentence( $_ ); } map { $self->_extractor_sentence_builder->build( $_ , $instance ); } grep { length( $_ ) && $_ !~ m/^\p{Punct}+$/ } @{ $sentences_raw_unfiltered };

    return \@sentences_filtered;

};

requires('extract_sentences');
requires('sentence_builder');

1;
