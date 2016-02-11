package Web::Summarizer::StringSequence;

use strict;
use warnings;

use StringNormalizer;
use Web::Summarizer::Token;

use Function::Parameters qw/:strict/;
use Memoize;

use Digest::MD5 qw/md5_hex/;
use Encode;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::Sequence' );

# raw string
has 'raw_string' => ( is => 'ro' , isa => 'Str' , required => 1 );

# TODO : how can we avoid replicating this method here ? => is there a way to make raw_string optional ?
sub filter {
    
    my $this = shift;
    my $filter = shift;
    
    my @filtered_sequence = grep { $filter->( $_ ); } @{ $this->object_sequence };

    return __PACKAGE__->new( object => $this->object ,
		       object_sequence => \@filtered_sequence ,
		       raw_string => join ( ' ' , map { $_->surface } @filtered_sequence ) ,
		       source_id => join( "." , $this->source_id , 'filtered' ) );

}

# hash key builder
sub _hash_key_builder {
    my $this = shift;
    my $hash_key = md5_hex( encode_utf8( $this->raw_string ) );
}

# sequence construction for string sequences
sub _object_sequence_builder {

    my $this = shift;

    # chunk string
    my $token_sequences_raw = $this->_tokenize;

    my @token_sequences_transformed;
    for ( my $component_id = 0 ; $component_id < scalar( @{ $token_sequences_raw } ) ; $component_id++ ) {
	my $token_sequence_raw = $token_sequences_raw->[ $component_id ];
	# TODO: transformer as a stateful object ?
	my $token_sequence_transformed = $this->token_transformer( $token_sequence_raw , $component_id );
	push @token_sequences_transformed , @{ $token_sequence_transformed };
    }

    return \@token_sequences_transformed;

}

# token transformer
sub token_transformer {

    my $this = shift;
    my $token_sequence = shift;

    # we filter out non-printable characters
    # Note : is thie the best place to test for the presence of at least one printable character ?
    # CURRENT : it should be about segmentation ! or normalization ?
    my @transformed_token_sequence = grep { $_->surface =~ m/\p{PosixPrint}/ } @{ $token_sequence };

    return \@transformed_token_sequence;

}

# default tokenization - to be overridden by sub-classes
sub _tokenize {

    my $this = shift;

    # tokenize string using basic tokenizer
    # TODO : abstract the full tokenization process (i.e. including the generation of Token objects)
    my $basic_tokens = $this->object->tokenizer->tokenize ( $this->raw_string );

    # generate sequence
    my @token_sequence = map { new Web::Summarizer::Token( surface => $_ ); } @{ $basic_tokens };
    
    return [ \@token_sequence ];

}

# Note : definitely ok if we assume that the sequence of object is immutable
# TODO : should we add support for mutability ?
has '_verbalized_sequence' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_verbalized_sequence_builder' );
sub _verbalized_sequence_builder {
    my $this = shift;
    return join( " " , map { $_->surface } @{ $this->object_sequence } );
}

# TODO: is this generic enough ?
sub verbalize {

    my $this = shift;
    
    # TODO: add generic parameter or is it the responsibility of the sub-classes ?    
    return $this->_verbalized_sequence;

}

# TODO : to be integrated with Modality::ModalityBase::supports_regex
sub supports_regex {

    my $this = shift;

    # TODO : control over the type of regex is left to the client (in particular to the Modality this Sequence belongs to)
    my $regex = shift;

=pod
    # CURRENT : only the Modality object knows about fluency ?
    if ( ref( $regex ) ne 'Regexp' ) {
	# i.e. this is a Token object
	$regex = $this->fluent ? $regex->as_regex : $regex->as_regex_anywhere;
    }
=cut

    my @all_matches;

    my $segment_copy = $this->raw_string;
    while ( my @matches = ( $segment_copy =~ $regex ) ){
	push @all_matches , \@matches;
	$segment_copy = substr $segment_copy , $+[ 0 ];
    }

    my $n_matches = scalar( @all_matches );
    return $n_matches ? \@all_matches : undef;

}

# TODO : does this really belong here ?
method lcs_similarity ( $sequence , :$normalize = 0 , :$keep_punctuation = 1 ) {
    
    my @sequences = map {
	my @tokens;
	foreach my $token (@{ $_ }) {
	    my $token_surface = ref( $token ) ? $token->surface : $token;
	    if ( !$keep_punctuation && ( ref( $token ) ? $token->is_punctuation : ( $token_surface =~ m/^\p{PosixPunct}+$/ ) ) ){
		next;
	    } 
	    push @tokens , ( $normalize ? StringNormalizer::_normalize( $token_surface ) : $token_surface );
	}
	\@tokens;
    } ( $self->object_sequence , ( ( ref( $sequence ) eq 'ARRAY' ) ? $sequence : $sequence->object_sequence ) );
    
    return Similarity->lcs_similarity( @sequences );

}

__PACKAGE__->meta->make_immutable;

1;
