package Modality::NgrammableModality;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with 'Modality' => { id => 'test' };
#extends('Modality');

# n-gram data loader
has 'ngram_data_loader' => ( is => 'ro' , isa => 'CodeRef' , predicate => 'has_ngram_data_loader' );

# n-gram min order
has 'ngram_min_order' => ( is => 'ro' , isa => 'Num' , required => 1 );

# n-gram max order
has 'ngram_max_order' => ( is => 'ro' , isa => 'Num' , required => 1 );

# n-gram count threshold
has 'ngram_count_threshold' => ( is => 'ro' , isa => 'Num' , required => 1 );

__PACKAGE__->meta->make_immutable;

1;
