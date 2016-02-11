package Web::Summarizer::Support;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# [ token/regex , n_matches , utterances , matches ]

# token
has 'token' => ( is => 'ro' , isa => 'Any' , required => 1 );

# utterances
has 'utterances' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# matches
# CURRENT : the matches would need to be attached to each utterance, there might be multiple matches per utterance
# ...

# modality_counts
# Note : this is the central piece of information - updated by all write primitives
has 'modality_counts' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

sub match_count {
    my $this = shift;
    my $count = 0;
    map { $count += $_ } values( %{ $this->modality_counts } );
    return $count;
}

# add modality matches
# TODO : add indexing ?
sub add_modality_matches {

    my $this = shift;
    my $source_id = shift;
    my $utterances = shift;

    if ( ! defined( $this->utterances->{ $source_id } ) ) {
	$this->utterances->{ $source_id } = [];
    }
    push @{ $this->utterances->{ $source_id } } , @{ $utterances };

    # update modality count
    $this->add_modality_matches_count( $source_id , scalar( @{ $utterances } ) );

}

sub add_modality_matches_count {

    my $this = shift;
    my $source_id = shift;
    my $count = shift;
    
    $this->modality_counts->{ $source_id } += $count;

}

__PACKAGE__->meta->make_immutable;

1;
