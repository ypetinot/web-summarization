package ReferenceTargetDecoder;

# Base decoder role for mappings where input is a raw input object (the target) together with a set of references (input,output) pairs.
# CURRENT : how can we require the associated model to be of type / do ReferenceTargetModel ?
# CURRENT : make model a subpart of the decoder (seems fair) , apply Trainable role to decoder instead of summarizer ==> Summarizer only includes or applies Decoder role

# Note : the decoder role implicily defines the underlying space that is being explored , additionally the the decoder may choose to include a model in which case it can be trained.

use strict;
use warnings;

# TODO : parameterize on Model type ?
use Moose::Role;

# decoder params
# TODO : add Trait to *_class attributes so that the corresponding class gets loaded automatically
has 'decoder_params' => ( is => 'ro' , isa => 'HashRef[Str]' , default => sub { {} } );

=pod
# decoder
# Note: the edge cost is part of the decoder to allow to test different cost schemes using the same graph (should make sense this way)
# Note: in that case should features and feature weights also be part of the decoder ?
has 'decoder' => ( is => 'ro' , does => 'Decoder' , init_arg => undef , lazy => 1 , builder => '_decoder_builder' );
#, handles => [ qw( decode ) ] );
sub _decoder_builder {
    my $this = shift;
    my %decoder_params = %{ $this->decoder_params };
    $decoder_params{ 'model' } = $this->model;
    my $decoder = ( Web::Summarizer::Utils::load_class( $this->decoder_class ) )->new( %decoder_params );
    return $decoder;
}

# TODO : why can't this be implemented via delegation ???
sub decode {
    return $_[ 0 ]->decoder->decode( @_ );
}
=cut

# TODO : create intermediary role (ModelDecoder ?) to account for the specificities of model-based decoders
with('Decoder');

1;
