package Modality::Operator::StringSegmenter;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# _id
# TODO : turn into role parameter for Modality::Operator
has '_id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , default => 'segmented' );

# segmentation function
has 'segmenter' => ( is => 'ro' , isa => 'CodeRef' , required => 1 );

sub segmented {

    my $this = shift;
    my $url_data = shift;
    my $parent_operator = shift;

    # 1 - get raw data
    my $raw_data = $parent_operator->run;

    # 2 - segment raw data
    # CURRENT : what if the operator was just working on top of the UrlData object ? i.e. no layers ?
    my $segmented_data = $this->segmenter->( $url_data , $raw_data )

}

with( 'Modality::Operator' );

__PACKAGE__->meta->make_immutable;

1;
