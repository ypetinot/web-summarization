package Web::Extractor::MetaSentencesExtractor;

use strict;
use warnings;

#use Moose::Role;
use MooseX::Role::Parameterized;
#use namespace::autoclean;

parameter source => (
    isa => 'Str',
    required => 1
    );

role {

    my $p = shift;
    my $_source = $p->source;

    # source
    has 'source' => ( is => 'ro' , isa => 'Str' , default => $_source );

# TODO : applied to summarizer ?
    method "extract_sentences" => sub {

	my $this = shift;
	my $instance = shift;
	
	my @raw_sentences;

	my $do_content = ( $this->source eq 'content' );
	my $do_context = ( $this->source eq 'context' );
	my $do_reference = ( $this->source eq 'reference' );
	my $do_all = ( $this->source eq 'all' );

	if ( $do_content || $do_all ) {
	    push @raw_sentences , @{ $this->extract_sentences_content( $instance ) || [] };
	}
	
	if ( $do_context || $do_all ) {
	    push @raw_sentences , @{ $this->extract_sentences_context( $instance ) || [] };
	}
	
	if ( $do_reference || $do_all ) {
	    push @raw_sentences , @{ $this->extract_sentences_reference( $instance ) || [] };
	}
	
	return \@raw_sentences;
	
    };

    with 'Web::Extractor::ContentSentencesExtractor' => {
	-alias => { 'extract_sentences' => 'extract_sentences_content' },
	-excludes => 'extract_sentence',
    },
    'Web::Extractor::ContextSentencesExtractor' => {
	-alias => { 'extract_sentences' => 'extract_sentences_context' },
	-excludes => 'extract_sentence',
    },
    'Web::Extractor::ReferenceSentencesExtractor' => {
	-alias => { 'extract_sentences' => 'extract_sentences_reference' },
	-excludes => 'extract_sentence',
    };

};

#__PACKAGE__->meta->make_immutable;

1;
