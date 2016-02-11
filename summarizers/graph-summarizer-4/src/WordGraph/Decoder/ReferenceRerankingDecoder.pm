package WordGraph::Decoder::ReferenceRerankingDecoder;

use strict;
use warnings;

use ReferenceTargetPairwiseModel;

#use Moose;
#use Moose::Role;
use MooseX::Role::Parameterized;

# TODO : this has to go, but how ?
parameter reference_construction_limit => (
    isa => 'Num',
    required => 0,
    default => 0
    );

parameter edge_model => (
    isa => 'Str',
    required => 1
    );

parameter no_filtering => (
    isa => 'Num',
    required => 0,
    default => 0
    );

parameter word_graph_transformations => (
    isa => 'ArrayRef',
    default => sub { [] }
    );

role {
    
    my $p = shift;
    my %params;
    $params{ k } = 50;
    my $slots = $p->meta->{_meta_instance}->{slots};
    map { $params{ $_ } = $p->{ $_ } } @{ $slots };

    with( 'WordGraph::Decoder::RerankingDecoder' => \%params );

=pod
    # filter length
    # TODO: can this be improved ?
    has 'filter_length' => ( is => 'ro' , isa => 'Num' , default => 8 );
=cut

=pod
    # filter out paths that are of length < 8 words and that do not contain a verb
    method "filter" => sub {

	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $path_entry = shift;
	
	my $path = $path_entry->[ 0 ];
	
	# TODO: how should we adjust the length threshold ?
	if ( ( $path->length() < $this->filter_length() ) || ! $this->_contains_verb( $path ) ) {
	    return 0;
	}
	
	return 1;
	
     };
=cut

     # normalize path cost by path length
     method ranking_score => sub {
    
	 my $this = shift;
	 my $graph = shift;
	 my $instance = shift;
	 my $path_entry = shift;
	 
	 my $corrected_path_score = $path_entry->[ 1 ] / $path_entry->[ 0 ]->length();

	 my $reference_target_pairwise_model = new ReferenceTargetPairwiseModel();

	 my $target_object = $instance->[ 0 ];
	 my $references = $instance->[ 1 ];
	 
	 my $reference_target_pairwise_instance = $reference_target_pairwise_model->create_instance( [ $target_object , $path_entry->[ 0 ] ] , $references );
	 my $unnormalized_probability = $reference_target_pairwise_instance->compute_unnormalized_probability();

	 return 1 / ( 0.0000001 + $unnormalized_probability );

     };

     # check whether the specified path contains a verb
     method "_contains_verb" => sub {

	 my $this = shift;
	 my $path = shift;
	 
	 foreach my $node ( @{ $path->node_sequence() } ) {
	     
	     if ( $node =~ m/^VB/i ) {
		 return 1;
	     }
	     
	 }

	 return 0;

       };

};

#__PACKAGE__->meta->make_immutable;

1;
