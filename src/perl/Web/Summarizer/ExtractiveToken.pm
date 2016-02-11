package Web::Summarizer::ExtractiveToken;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::Token' );

sub _surface_builder {
    my $this = shift;
    return '<this-is-a-test>';
}

# Note : this is an extractive slot (still needed ?)
has '+abstract_type' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'SLOT_EXT' );

# original object_sequence that this token stands for
has 'original_object_sequence' => ( is => 'ro' , isa => 'ArrayRef[Web::Summarizer::Token]' , required => 1 );

# extractive probability
# TODO : promote to parent class as just 'probability' ?
has 'extractive_probability' => ( is => 'ro' , isa => 'Num' , required => 1 );

sub original_sequence_length {
    my $this = shift;
    return scalar( @{ $this->original_object_sequence } );
}

sub _original_object_sequence_surfaces {
    my $this = shift;
    my @sequence_surfaces = map { $_->surface } @{ $this->original_object_sequence };
    return \@sequence_surfaces;
}

sub original_sequence_pattern_regex {
    my $this = shift;
    my $sequence_pattern = join( '\s+' , @{ $this->_original_object_sequence_surfaces } );
    my $sequence_pattern_regex = qr/$sequence_pattern/si;
    return $sequence_pattern_regex;
}

sub original_sequence_surface {
    my $this = shift;
    my $sequence_surface = join( ' ' , @{ $this->_original_object_sequence_surfaces } );
    return $sequence_surface;
}

__PACKAGE__->meta->make_immutable;

1;
