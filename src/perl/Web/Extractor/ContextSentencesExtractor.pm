package Web::Extractor::ContextSentencesExtractor;

use strict;
use warnings;

use JSON;
use Text::Trim;

use Moose::Role;
#use namespace::autoclean;

# TODO : applied to summarizer ?
sub extract_sentences {

    my $this = shift;
    my $instance = shift;

    my $anchortext = $instance->get_field( 'anchortext' );;
    my $anchortext_data = decode_json( $anchortext );
    my @raw_sentences = grep { length($_); } map { @{ $_->{'sentence'} } } grep { defined( $_->{'sentence'} ) } @{ $anchortext_data };

    #my @context_sentences = map { $this->sentence_builder->build( $_ , $instance ); } grep { length( $_ ) && $_ !~ m/^\p{Punct}+$/ } @raw_sentences;

    return \@raw_sentences;

}

with('Web::Extractor::SentenceExtractor');

#__PACKAGE__->meta->make_immutable;

1;
