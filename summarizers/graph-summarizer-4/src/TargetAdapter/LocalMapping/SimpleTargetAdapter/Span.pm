package TargetAdapter::LocalMapping::SimpleTargetAdapter::Span;

use strict;
use warnings;

use Carp::Assert;
use List::MoreUtils qw/uniq/;

use Moose::Role;

# range sequence
has '_range_sequence' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_range_sequence_builder' );
sub _range_sequence_builder {

    my $this = shift;
    my $from = $this->from;
    my $to = $this->to;

    my @range_sequence;

    if ( $from == $to ) {
	@range_sequence = ( $from );
    }
    else {
	@range_sequence = ( $from .. $to );
    }

    return \@range_sequence;
    
}

# neighborhood
has 'neighborhood' => ( is => 'ro' , isa => 'Web::Summarizer::ReferenceTargetSummarizer::Neighborhood' , required => 1 );

# priors
has 'priors' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_priors_builder' );
sub _priors_builder {

    my $this = shift;

    my $neighborhood = $this->neighborhood;

    my $from = $this->from;
    my $to = $this->to;

    my @priors = map {

	my $i = $_;

	my $current_token = $this->original_sequence->object_sequence->[ $i ];
	$this->neighborhood->prior( $current_token , ignore => $this->original_sequence->object );


    } @{ $this->_range_sequence };

    return \@priors;

}

# TODO : reliance on this field should be removed eventually
has 'component_id' => ( is => 'ro' , isa => 'Num' , required => 1 , lazy => 1 , builder => '_component_id_builder' );

sub span_prior {

    my $this = shift;

    my $from = shift;
    my $to = shift;

    # Note : this cannot be kept here without integrated support for components
    #affirm { ( $from >= $this->from ) && ( $to <= $this->to ) } "Requested span must be within the defined bounds: $from / $to /// " . join( " / " , $this->from , $this->to ) if DEBUG;
    
    # TODO : theoretical justification ?
    my $prior_sum = 0;
    my $n = $to - $from + 1;
    map {
	my $token_prior = $this->priors->[ $_ ];
	$prior_sum += $token_prior;
    } uniq ( $from .. $to );

    return $prior_sum / $n;

}

# from => by default ends at the beginning of the original sequence
has 'from' => ( is => 'ro' , isa => 'Num' , required => 1 );

# to => by default ends at the end of the original sequence
has 'to' => ( is => 'ro' , isa => 'Num' , required => 1 );

# length
has length => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_length_builder' );
sub _length_builder {
    my $this = shift;
    return ( $this->to - $this->from + 1 );
}

1;
