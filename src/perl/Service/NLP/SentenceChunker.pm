package Service::NLP::SentenceChunker;

use strict;
use warnings;

use Service::NLP::Dependency;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'Service::NLP::SentenceAnalyzer' );
with( 'Service::ThriftBased' => { host => $ENV{ SERVICE_HOST } , port => 8888 , client_class => 'CoreNLP::StanfordCoreNLPClient' } );

sub _use_shift_reduce_parser_builder {
    return 1;
}

sub run {

    my $this = shift;
    my $sentence = shift;
    my $options = shift || [];

    # 1 - normalize sentence string
    my $normalized_sentence = $this->normalize_sentence( $sentence );
    
    # CURRENT/TODO : what if the sentence is actually many sentences ?
    return $this->chunk( $normalized_sentence , $options , 'pos' );

}

sub get_named_entities {

    my $this = shift;
    my $sentence = shift;

    # TODO : how can we reduce code duplication with run/chunk ?

    # 1 - normalize sentence string
    my $normalized_sentence = $this->normalize_sentence( $sentence );

    # Note: as much as possible, optimize entity detection => the goal is to reduce the load on the Stanford service
    if ( $normalized_sentence =~ m/^\d+$/ ) {
	return [ new CoreNLP::NamedEntity( { startOffset => 0 , entity => $normalized_sentence , sentence_number => 0 , endOffset => length( $normalized_sentence ) + 1 , tag => 'NUMBER' } ) ];
    }
    elsif ( length( $normalized_sentence ) ) {
	# TODO : can we avoid this ?
	my $thrift_client = Service::NLP::SentenceChunker->new->_client;

	$this->logger->debug( "[" . __PACKAGE__ . "] Extracting Named Entities: $normalized_sentence" );
	if ( ! utf8::is_utf8( $normalized_sentence ) ) {
	    $this->logger->debug( "String is not utf8 prior to parsing : $normalized_sentence" );
	}

	my $thrift_output = $thrift_client->get_entities_from_text( $normalized_sentence );
	if ( ! defined( $thrift_output ) ) {
	    $this->warn( "Potential issue during named entity extraction on: $normalized_sentence" );
	}
	return $thrift_output;
    }

    return [];

}

__PACKAGE__->meta->make_immutable;

1;
