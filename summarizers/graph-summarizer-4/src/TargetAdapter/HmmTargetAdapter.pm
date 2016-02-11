package TargetAdapter::HmmTargetAdapter;

use strict;
use warnings;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Temp;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter' );

has _transition_probabilities => ( is => 'ro' , isa => 'HashRef' . init_arg => undef , lazy => 1 , builder => '_transition_probabilities_builder' );
sub _transition_probabilities_builder {
    my $this = shift;
    my %transition_probabilities;
    # TODO : where do we load this from ?
    return \%transition_probabilities;
}

has _emission_probabilities => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_emission_probabilities_builder' );
sub _emission_probabilities_builder {
    my $this = shift;
    # CURRENT : not sure what is needed here ... for now focus on data production and training process ...
}

sub _adapt {

    my $this = shift;
    my $original_sentence = shift;
    my $alignment = shift;

    # create new sentence object
    my $adapted_sentence = new Web::Summarizer::Sentence( object_sequence => $adapted_sequence , object => $this->target ,
							  source_id => join( '.' , $original_sentence->source_id , 'adaptated' ) );
    
    
    return $adapted_sentence;

}

__PACKAGE__->meta->make_immutable;

1;
