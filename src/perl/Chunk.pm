package Chunk;

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use StringNormalizer;

use Lingua::Stem qw(stem);

my $__ABSTRACTED_TERM__ = '*';

with Storage('format' => 'JSON', 'io' => 'File');

# ********************************************************************************* #
# fields 

# chunk id
has 'id' => (is => 'ro', isa => 'Num', required => 1);

# type (POS)
has 'type' => (is => 'ro', isa => 'Str', required => 1);

# count
has 'count' => (is => 'ro', isa => 'Num', required => 1);

# surface form
has 'surface' => (is => 'ro', isa => 'Str', required => 1);

# semantics
has 'semantics' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

# terms
has 'terms' => (is => 'rw', isa=> 'ArrayRef', default => sub { {} });

# ********************************************************************************* #

# constructor
sub BUILD {

    my $this = shift;

    # init object
    $this->init();

}

# initialization
sub init {

    my $this = shift;

}

# check if this is an np chunk/node
sub is_np {

    my $this = shift;

    if ( $this->type() eq 'np' ) {
	return 1;
    }

    return 0;

}

# get number of terms in this Chunk
sub get_number_of_terms {

    my $this = shift;

    return scalar( @{ $this->{terms} } );

}

# get term at the specified index
sub get_term {

    my $this = shift;
    my $index = shift;

    if ( $index < 0 || $index >= $this->get_number_of_terms() ) {
	return undef;
    }

    return $this->terms()->[ $index ]->{ 'normalized' };

}

# get term entry at the specified index
sub get_term_entry {

    my $this = shift;
    my $index = shift;

    return $this->terms()->[ $index ];

}

# get terms in this Chunk
sub get_terms {

    my $this = shift;

    my @all_terms = map { $_->[0]; } @{ $this->terms() };

    return \@all_terms;

}

# abstract a specific term
sub abstract_term {

    my $this = shift;
    my $term = shift;

    $this->{_terms}->{$term}->{surface} = $__ABSTRACTED_TERM__;

}

# chunk placeholder string
sub placeholder {

    my $this = shift;
    
    my $placeholder = join("", $this->placeholder_prefix(), $this->{id}, $this->placeholder_suffix());

    return $placeholder;

}

# chunk placeholder prefix string (static)
sub placeholder_prefix {

    my $this = shift;
    
    return "__chunk_";

}

# chunk placeholder suffix string (static)
sub placeholder_suffix {

    my $this = shift;
    
    return "__";

}

# chunk placeholder matcher (static)
sub placeholder_matcher {

    my $this = shift;
    
    my $placeholder_regex_string = join("", $this->placeholder_prefix(), '\d+', $this->placeholder_suffix());
    my $placeholder_regex = qr/$placeholder_regex_string/;

    return $placeholder_regex;

}

# chunk matcher
sub chunk_matcher {

    my $this = shift;

    my $elementary_regex_sub = sub {

	my $chunk = shift;
	my $regex_string = lc(join( " " , map { $_->{ 'normalized' } ; } @{ $this->terms() }));

	return "$regex_string";

    };

    my @chunk_regex_components;
    push @chunk_regex_components, $elementary_regex_sub->( $this );

    my $chunk_regex_string = join("|", map { "(?:\Q$_\E)"; } @chunk_regex_components);
    my $chunk_regex = qr/(?:$chunk_regex_string)/i;

    return $chunk_regex;

}

# store model for this chunk
sub set_model {

    my $this = shift;
    my $model = shift;

    $this->{_model} = $model;

}

# get model for this chunk
sub get_model {

    my $this = shift;

    return $this->{_model};
    
}

# get representative string
sub get_representative_string {

    my $this = shift;

    return $this->surface();

}

# get surface string
sub get_surface_string {

    my $this = shift;

    return join(' ', map { $_->{ 'normalized' }; } @{ $this->terms() });

}

# get length
sub get_length {

    my $this = shift;
    
    return scalar( @{ $this->terms() } );

}

=pod
    foreach my $chunk_element (@chunk_elements) {
	
	# This/DT/B-NP is/VBZ/B-VP a/DT/B-NP sample/NN/I-NP sentence/NN/I-NP to/TO/B-VP see/VB/I-VP
	# whether/IN/B-SBAR this/DT/B-NP NP/NNP/I-NP chunker/NN/I-NP is/VBZ/B-VP working/VBG/I-VP
	# in/IN/B-PP New/NNP/B-NP York/NNP/I-NP ././O

	if ( $chunk_status eq 'B-NP' ) {
	    if ( scalar(@buffer) ) {
		update_np_stats(\@buffer, \@summary);
	    }
	    @buffer = ( $chunk_element );
	}
	elsif ( $chunk_status ne 'I-NP' ) {
	    if ( scalar(@buffer) ) {
		update_np_stats(\@buffer, \@summary);
	    }
	    @buffer = ();
	    push @summary, $chunk_element;
	}
	else {
	    push @buffer, $chunk_element;
	}

    }
    
    push @chunked_summaries, \@summary;

}
=cut

1;
