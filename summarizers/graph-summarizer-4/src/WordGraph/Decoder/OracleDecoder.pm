package WordGraph::Decoder::OracleDecoder;

use List::MoreUtils qw/uniq/;

use Web::Summarizer::SentenceAnalyzer;

use Moose;

extends 'WordGraph::Decoder::RerankingDecoder';

# max n-gram order
has 'ngram_order_max' => ( is => 'ro' , isa => 'Num' , required => 1 );

# sentence analyzer
has 'sentence_analyzer' => ( is => 'ro' , isa => 'Web::Summarizer::SentenceAnalyzer' ,
			     default => sub { { return new Web::Summarizer::SentenceAnalyzer(); } } );

# oracle paths
has 'oracle_sequences' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } , lazy => 1 );

# oracle graph path stats
has 'oracle_graph_paths_stats' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } , lazy => 1 );

sub BUILDARGS {

    my $class = shift;
    my %_orig  = @_;
    
    $_orig{ 'k' } = 50;
    #$_orig{ 'ranker' } = \&oracle_ranker;

    return \%_orig;
    
}

# compute score based on oracle prediction
# TODO: this should really be a sort function
sub ranking_score {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;
    my $path_entry = shift;
 
    my $instance_url = $instance->url();

    if ( ! defined( $this->oracle_sequences()->{ $instance_url } ) ) {
	$this->oracle_sequences()->{ $instance_url } = $graph->graph_constructor()->sentence_builder()->build( $instance->get_field( 'summary.chunked.refined' ) , $instance );
    }

    # compute overlap between path entry and oracle path
    # Is there a better way ? --> this necessarily relies on search, so probably not
    my $coverage_score = $this->coverage_score( $graph , $instance , $this->oracle_sequences()->{ $instance_url } , $path_entry->[ 0 ] );

    return $coverage_score;
    
}

sub _graph_path_stats {

    my $this = shift;
    my $graph = shift;
    my $target_sequence = shift;

    # aggregate stats
    my %aggregate_stats;

    # compute coverage stats for every known valid path in the graph
    my $graph_paths = $graph->paths();
    foreach my $graph_path (values( %{ $graph_paths })) {

	my $path_coverage = $this->sentence_analyzer()->analyze( $target_sequence , $graph_path->as_sentence() );
	foreach my $path_coverage_difference_entry (@{ $path_coverage }) {
	    map {
		$aggregate_stats{ $_ } += 1;
	    } keys( %{ $path_coverage_difference_entry } );
	}

    }

    return \%aggregate_stats;
    
}

# for each ngram
# --> frequency in target sequence
# --> frequency in reference sequences (use paths)
# * missing ngrams that also appear in graph
# * included ngrams that do no appear in target
# * included ngrams that appear in target
sub coverage_score {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;
    my $target_sequence = shift;
    my $path = shift;

    my $instance_url = $instance->url();

=pod
    # get reference coverage for graph paths
    if ( ! defined( $this->oracle_graph_paths_stats()->{ $instance_url } ) ) {
	$this->oracle_graph_paths_stats()->{ $instance_url } = $this->_graph_path_stats( $graph , $target_sequence );
    }
    my $graph_paths_coverage = $this->oracle_graph_paths_stats()->{ $instance_url };
=cut

    # compute ngram coverage for current path
    my $current_path_coverage = $this->sentence_analyzer()->analyze( $target_sequence , $path->as_sentence() );

=pod
    foreach my $coverage_entry ( @{ $current_path_coverage } ) {
	map {
	    my $difference = $coverage_entry->{ $_ };
	    $coverage_score += abs( $difference * ( 1/ ( $graph_paths_coverage->{ $_ } || 0.0000001 ) ) );
	} keys( %{ $coverage_entry } );
    }
=cut

    # compute score by averaging all f-measure scores ?
    # TODO: this should be handled as a sort function
    my $coverage_score = 0;
    map { $coverage_score += ( 1 - $current_path_coverage->{ $_ } ) ; } grep { $_ =~ m/fmeasure/si; } keys( %{ $current_path_coverage } );
    
    return $coverage_score;
    
}

=pod
sub compute_ngram_coverage {

    my $this = shift;
    my $graph = shift;
    my $target_sequence = shift;
    my $path = shift;

    # get raw ngram coverage data
    my $raw_ngram_coverage = $this->_compute_ngram_coverage( $graph , $target_sequence , $path );

    # generate aggregate data
    my %aggregate_ngram_coverage;
    foreach my $raw_ngram_coverage_entry_difference (@{ $raw_ngram_coverage }) {
	map {
	    my $ngram_key = join( "-" , $raw_ngram_coverage_entry_ngram_order , $_ );
	    $aggregate_ngram_coverage{ $ngram_key } += 1;
	} keys( %{ $raw_ngram_coverage_entry_difference } );
    }

    return \%aggregate_ngram_coverage;

}
=cut

no Moose;

1;
