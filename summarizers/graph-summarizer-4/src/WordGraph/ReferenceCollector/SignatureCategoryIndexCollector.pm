package WordGraph::ReferenceCollector::SignatureCategoryIndexCollector;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector::SignatureIndexCollector' );

sub _run {

    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    # 1 - get initial set of references
    # TODO : work on dynamically adjusting the set of query terms
    my $raw_references = $this->SUPER::_run( $target_object , $reference_object_data , $reference_object_id );

    # 2 - count categories
    my %category2count;
    foreach my $raw_reference (@{ $raw_references }) {
	my $category = $raw_references->get_field( 'category' , namespace => 'dmoz' );
	$category2count{ $category }++
    }

    # CURRENT (easy) : filter based on signature and then pick most central summary
    # CURRENT : maybe retrieve/identify most likely category based on search results, then identify most central summary that also covers search terms
    # CURRENT : centroid-based ranking

    # TODO : ideally we should directly query an index of category profiles but doing this can be seen a first step in that direction
    # 3 - generate category profiles ?
    my @category_profiles = map {
	$this->generate_category_profile( $_ );
    } keys( %category2count );

    # 4 - rank based on category profile

    # 3 - filter based on signature
    # CURRENT :
    # (1) - distribution of positive probability
    # (2) - assume normaly distributed => only consider 1 standard deviation from the mean
    my @signature_terms = keys( %{ $signature_query_terms } );
    my %reference_2_support;
    foreach my $reference_object (@{ $reference_objects }) {

	my $count_positive = 0;
	my $count_negative = 0;
	my $count_total = 0;

	foreach my $signature_term (@signature_terms) {
	    if ( $reference_object->summary_modality->supports( $signature_term ) ) {
		$count_positive++;
	    }
	}

	foreach my $reference_summary_token ( @{ $reference_object->summary_modality->utterance->object_sequence } ) {
	    if ( $reference_summary_token->is_punctuation ) {
		next;
	    }
	    elsif ( ! $target_object->supports( $reference_summary_token ) ) {
		$count_negative++;
	    }
	}

	if ( $count_total ) {
	    my $signature_support = ( $count_positive / ( $count_negative || 1 ) );
	    $reference_2_support{ $reference_object->url } = $signature_support;
	}

    }

    # compute support stats
    my @support_values = values( %reference_2_support );
    my $support_mean = mean( @support_values );
    my $support_stddev = stddev( @support_values );

    # Note : the idea is ultimately to rerank but only within a tier of similar-quality summaries
    # TODO: create tiers based on support ratio => only return top tier
    my @final_reference_objects =
	#grep {
	#    abs( ( $reference_2_support{ $_->url } - $support_mean ) ) <= 2 * $support_stddev;
    #} grep { defined( $reference_2_support{ $_->url } ) }
    @{ $reference_objects };

    $this->logger->debug( "Reenable signature filtering once I have fine-tuned the adaptation algorithm ..." );
    ###return \@final_reference_objects;

    return $reference_objects;

}

__PACKAGE__->meta->make_immutable;

1;
