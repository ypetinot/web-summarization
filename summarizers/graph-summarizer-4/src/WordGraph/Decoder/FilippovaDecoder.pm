package WordGraph::Decoder::FilippovaDecoder;

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

    # filter length
    # TODO: can this be improved ?
    has 'filter_length' => ( is => 'ro' , isa => 'Num' , default => 8 );

=pod # to be removed, now handled through role parameters
sub BUILDARGS {

    my $class = shift;
    my %_orig  = @_;
    
    $_orig{ 'k' } = 50;
    #$_orig{ 'filter' } = \&filter;
    #$_orig{ 'ranker' } = \&ranker;

    return \%_orig;
    
}
=cut

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

     # normalize path cost by path length
     method ranking_score => sub {
    
	 my $this = shift;
	 my $graph = shift;
	 my $instance = shift;
	 my $path_entry = shift;
	 
	 my $corrected_path_score = $path_entry->[ 1 ] / $path_entry->[ 0 ]->length();
	 
	 return $corrected_path_score;

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
