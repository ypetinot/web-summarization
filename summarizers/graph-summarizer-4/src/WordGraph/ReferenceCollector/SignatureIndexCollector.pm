package WordGraph::ReferenceCollector::SignatureIndexCollector;

use strict;
use warnings;

use Web::Summarizer::UrlSignature;

use Statistics::Basic qw(:all);

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector::IndexCollector' );

has '_url_signature' => ( is => 'ro' , isa => 'Web::Summarizer::UrlSignature' , init_arg => undef , lazy => 1 , builder => '_url_signature_builder' );
sub _url_signature_builder {
    my $this = shift;
    return new Web::Summarizer::UrlSignature( global_data => $this->global_data );
}

sub _word_length {
    my $string = shift;
    my $n_components = scalar( split /\s+/ , $string );
    return $n_components;
}

sub _query_terms {

    my $this = shift;
    my $target_object = shift;

    # 0 - generate target object signature
    my $target_object_signature = $this->_url_signature->compute( $target_object );

=pod # old verion (works decently as far as I could tell
    # 1 - select source utterances (for now limited to page content)
    my $source_utterances = $target_object->content_modality->utterances;
    my @selected_utterances = grep { _word_length( $_ ) <= 3 } @{ $source_utterances };

    # 2 - generate query terms from selected utterances
    my %selected_terms;
    foreach my $selected_utterance (@selected_utterances) {
	my @selected_utterance_terms = map { $_->surface } @{ $selected_utterance->object_sequence };
	map { $selected_terms{ $_ }++; } @selected_utterance_terms;
    }
=cut
    my %selected_terms = %{ $target_object_signature->coordinates };

    # truncate selected terms => this feels like the best way to remove noise
    my @sorted_terms = sort { $selected_terms{ $b } <=> $selected_terms{ $a } } keys( %selected_terms );
    if ( $#sorted_terms > 20 ) {
	splice @sorted_terms , 20;
    }
    my %selected_terms_final;
    map { $selected_terms_final{ $_ } = $selected_terms{ $_ } } @sorted_terms;

    #return \%selected_terms;
    return \%selected_terms_final;

}

sub _run {

    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    # 1 - get full list of query terms
    my $signature_query_terms = $this->_query_terms( $target_object );

    # 2 - query index
    my $reference_objects = $this->_query_index( $signature_query_terms );

    # CURRENT (easy) : filter based on signature and then pick most central summary
    # CURRENT : maybe retrieve/identify most likely category based on search results, then identify most central summary that also covers search terms
    # CURRENT : centroid-based ranking

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

	my $reference_object_summary = $reference_object->summary_modality->utterance;
	if ( ! $reference_object_summary ) {
	    next;
	}

	foreach my $signature_term (@signature_terms) {
	    if ( $reference_object->summary_modality->supports( $signature_term ) ) {
		$count_positive++;
	    }
	}

	foreach my $reference_summary_token ( @{ $reference_object_summary->object_sequence } ) {
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
