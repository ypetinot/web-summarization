package Service::NLP::SentenceAnalyzer;

use strict;
use warnings;

use Carp::Assert;
use CoreNLP::StanfordCoreNLP;
use Encode;
use utf8;

use Moose;
use namespace::autoclean;

extends( 'Service::Local' );

has 'use_shift_reduce_parser' => ( is => 'ro' , isa => 'Bool' , lazy => 1 , builder => '_use_shift_reduce_parser_builder' );

sub normalize_sentence {
    my $this = shift;
    my $sentence_string_raw = shift;
    
    my $sentence_string_normalized = $sentence_string_raw;

    # replace backticks with apostrophes
    while ( $sentence_string_normalized =~ s/\`/\'/sg ) {}

    my $sentence_string_normalized_length = length( $sentence_string_normalized );
    if ( $sentence_string_normalized_length ) {
	
	# compute ratio of latin characters to non-latin characters
#	my @latin_matches = $sentence_string_normalized =~ m/(?:\p{Latin}|\p{PosixPunct}|\p{Space})/sig;
	my @latin_matches = ( $sentence_string_normalized =~ m/(\p{ASCII}+)/sig );
	my $latin_matches_length = 0;
	map { $latin_matches_length += length( $_ ); } @latin_matches;
	my $latin_character_ratio = $latin_matches_length / $sentence_string_normalized_length;
	if ( $latin_character_ratio < 0.5 ) {
		
	    $this->logger->warn( "Stripping sentence string of non-latin character as this type of strings seems to not be supported by the Stanford parsers ... to be fixed" );
	    
	    $sentence_string_normalized = join( '' , @latin_matches );
		
	}

    }

    return $sentence_string_normalized;
}

sub chunk {

    my $this = shift;
    my $string = shift;
    my $options = shift;
    my $label = shift || '';

    # thrift version
    # CURRENT : how to make this call while allowing the creation of a wrapper around it to process potential exception in Service::ThriftBased ?
    #my $thrift_output = $this->_client->parse_text( $string , undef );

    if ( length( $string ) ) {

	my $thrift_client = $this->new->_thrift_client;

	$this->logger->debug( "($label) Parsing: $string" );
	if ( ! utf8::is_utf8( $string ) ) {
	    $this->logger->debug( "String is not utf8 prior to parsing : $string" );
	}

	my $thrift_output = $this->use_shift_reduce_parser ? $thrift_client->sr_parse_text( $string , $options ) : $thrift_client->parse_text( $string , $options );;
	if ( ! defined( $thrift_output ) || ! scalar( @{ $thrift_output } ) ) {
	    $this->warn( "($label) Potential issue during parsing of: $string" );
	}

	return $thrift_output;

    }

    return [];

}

sub parse_tokens {

    my $this = shift;
    my $tokens = shift;
    my $options = shift;
    my $label = shift || '';

    if ( scalar( @{ $tokens } ) ) {

	my $thrift_client = $this->_thrift_client;

	my $string = join( ' ' , @{ $tokens } );
	$this->logger->debug( "($label) Parsing (from tokens): $string" );
	if ( ! utf8::is_utf8( $string ) ) {
	    $this->logger->debug( "String (from tokens) is not utf8 prior to parsing : $string" );
	}

	my $thrift_output = $this->use_shift_reduce_parser ? $thrift_client->sr_parse_tokens( $tokens , $options ) : $thrift_client->parse_tokens( $tokens , $options );
	if ( ! defined( $thrift_output ) ) {
	    $this->warn( "($label) Potential issue during parsing (from tokens) of: $string" );
	}

	return $thrift_output;

    }

    return [];

}

sub _thrift_client {
    my $this = shift;
    # TODO : can we avoid this ?
    my $thrift_client = $this->new->_client;
    return $thrift_client;
}

__PACKAGE__->meta->make_immutable;

1;
