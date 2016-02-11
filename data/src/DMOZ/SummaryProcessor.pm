package DMOZ::SummaryProcessor;

use strict;
use warnings;

use String::Tokenizer;

use Moose;
use namespace::autoclean;

# keep punctuation ?
has 'keep_punctuation' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# processor
has 'processor' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_processor' );

sub generate_sequence {
    my $this = shift;
    my $raw_string = shift;
    return String::Tokenizer->tokenize( $raw_string , normalize_case => 1 , keep_punctuation => $this->keep_punctuation );
}

sub process {

    my $this = shift;
    my $raw_string = shift;

    # generate sequence associated with the raw string
    my $raw_sequence = $this->generate_sequence( $raw_string );
    
    # map sequence if requested
    my $final_sequence = $raw_sequence;
    if ( $this->has_processor ) {
	my @mapped_sequence = map { $this->processor->( $_ ) } @{ $raw_sequence };
	$final_sequence = \@mapped_sequence;
    }

    return $final_sequence;

}

# TODO : why ?
###__PACKAGE__->make_immutable;

1;
