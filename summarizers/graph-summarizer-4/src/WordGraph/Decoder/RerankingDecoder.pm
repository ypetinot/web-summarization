package WordGraph::Decoder::RerankingDecoder;

use strict;
use warnings;

use Clone qw/clone/;

#use Moose;
#use Moose::Role;
use MooseX::Role::Parameterized;

parameter k => (
    isa => 'Num',
    required => 1
    );

parameter no_filtering => (
    isa => 'Num',
    required => 0,
    default => 0
    );

# TODO : this has to go, but how ?
parameter reference_construction_limit => (
    isa => 'Num',
    required => 1
    );

parameter edge_model => (
    isa => 'Str',
    required => 1
    );

parameter word_graph_transformations => (
    isa => 'ArrayRef',
    default => sub { [] }
    );

role {

    my $p = shift;
    my $_k = $p->k;
    my $_no_filtering = $p->no_filtering;

    my %params;
    my $slots = $p->meta->{_meta_instance}->{slots};
    map { $params{ $_ } = $p->{ $_ } } @{ $slots };
    with( 'WordGraph::Decoder::ExactDecoder' => \%params );

    # no filtering ?
    has 'no_filtering' => ( is => 'ro' , isa => 'Bool' , default => $_no_filtering );
    
    # K - number of top shortest paths to consider for subsequent reranking
    has 'k' => ( is => 'ro' , isa => 'Num' , default => $_k );

    # filtering method (the default is to not filter)
    method "filter" => sub {

	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $entry = shift;
	
	return 1;

    };

    # reranking method (the default is to rerank by increasing cost)
    method "ranking_score" => sub {

	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $entry = shift;
	
	return $entry->[1];
	
    };

    our $DEBUG = 1;
    
    # find optimal path for the current set of weights
    method "_decode" => sub {
	
	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	
	# 1 - generate top-K shortest paths
	my $filter_coderef = sub { $this->filter(@_) };

	# CURRENT: this is where we are interfacing with whatever (edge) model is used, how do we make this happen ?
	my $shortest_paths = $graph->top_k_shortest_paths( $this->model , $this->k() , $instance , $filter_coderef );
	
	# 2 - rerank
	# TODO: should be optimized
	my @sorted_paths = sort { $this->ranking_score( $graph , $instance , $a ) <=> $this->ranking_score( $graph , $instance , $b ); } grep { $this->no_filtering() || $this->filter( $graph , $instance , $_ ) } @{ $shortest_paths };
	
	return ( scalar( @sorted_paths ) ? $sorted_paths[ 0 ]->[ 0 ] : undef , {} );
	
    };

};
    
#__PACKAGE__->meta->make_immutable;

1;
