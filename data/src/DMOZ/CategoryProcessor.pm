package DMOZ::CategoryProcessor;

use strict;
use warnings;

use File::Slurp;
use List::MoreUtils qw/uniq/;

use Moose;
use namespace::autoclean;

# category data
has 'category_data_file' => ( is => 'ro' , isa => 'Str' , required => 1 );

# keep punctuation
has 'keep_punctuation' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# processor
has 'processor' => ( is => 'ro' , isa => 'CodeRef' , required => 1 );

# summary processor
has 'summary_processor' => ( is => 'ro' , isa => 'DMOZ::SummaryProcessor' , init_arg => undef , lazy => 1 , builder => '_summary_processor_builder' );
sub _summary_processor_builder {
    my $this = shift;
    my $summary_processor = new DMOZ::SummaryProcessor( keep_punctuation => $this->keep_punctuation , processor => $this->processor );
    return $summary_processor;
}

# entries
has 'entries' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_entries_builder' );
sub _entries_builder {
    my $this = shift;
    my @entries = grep { scalar( @{ $_ } ); } map { my @fields = split /\t/ , $_;
						    ## TODO : this is what the original code was using as processor => backpropagate modification
						    #$this->summary_processor->generate_sequence( $fields[ 1 ] );
						    $this->summary_processor->process( $fields[ 1 ] );
    }
    # TODO : should the use of uniq be configurable ?
    uniq read_file( $this->category_data_file , chomp => 1 );
    return \@entries;
}

__PACKAGE__->meta->make_immutable;

1;
