package WordGraph::ReferenceRanker::CombinedRelevance;

use Web::Summarizer::Utils;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker' );

# TODO : could we just implement this using a builder that overrides the parent's class default value ?
has '+reversed' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# Component rankers
has 'component_rankers_configuration' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );
has 'component_rankers' => ( is => 'ro' , isa => 'ArrayRef[WordGraph::ReferenceRanker]' , init_arg => undef , lazy => 1 , builder => '_component_rankers_builder' );
sub _component_rankers_builder {

    my $this = shift;
    my @component_rankers = map {

	my $component_ranker_class = $_->[ 0 ];
	my $component_ranker_params = $_->[ 1 ];

	my %params = %{ $component_ranker_params };
	#$params{ category_repository } = $this->category_repository;
	#$params{ global_data } = $this->global_data;

	my $component_ranker_object = Web::Summarizer::Utils::load_class( $component_ranker_class )->new( %params );

    } @{ $this->component_rankers_configuration };

    return \@component_rankers;

}

our $REFERENCE_RANKING_MODE_COMBINED_RELEVANCE = "combined-relevance";
sub _id {
    return $REFERENCE_RANKING_MODE_COMBINED_RELEVANCE;
}

sub _run_implementation {

    my $this = shift;
    my $target_object = shift;
    my $reference_entries = shift;

    my %url_2_entry;

    # 1 - compute component rankings
    my @component_rankings = map {
	
	my $ranker = $_;
	my %ranking_hash;

	my $ranking = $ranker->run( $target_object , $reference_entries );
	my $n_entries = scalar( @{ $ranking } );
	    
	for (my $i=0; $i<$n_entries; $i++) {
	    
	    my $entry = $ranking->[ $i ]->[ 0 ];
	    my $entry_url = $entry->object->url;
	    
	    $ranking_hash{ $entry_url } = ( $i + 1 );
	    
	    if ( ! defined( $url_2_entry{ $entry_url } ) ) {
		$url_2_entry{ $entry_url } = $entry;
	    }
	    
	}

	\%ranking_hash;

    } @{ $this->component_rankers };

    # 2 - compute combined ranking
    my %url_2_combined_ranking;
    foreach my $url (keys( %url_2_entry )) {

	if ( ! defined( $url_2_combined_ranking{ $url } ) ) {
	    $url_2_combined_ranking{ $url } = 0;
	}

	map {
	    
	    # TODO : make combination operator a parameter
	    #( $url_2_object_relevance_ranking{ $_ } || 0 ) * ( $url_2_summary_relevance_ranking{ $_ } || 0 ); 

	    $url_2_combined_ranking{ $url } += $_->{ $url } || 0;

	} @component_rankings;

    }

    my @final_entries = map {
	[ $url_2_entry{ $_ } , $url_2_combined_ranking{ $_ } ]
    } keys( %url_2_combined_ranking );

    return \@final_entries;

}

__PACKAGE__->meta->make_immutable;

1;
