package Modality::SummaryModality;

# CURRENT : how to achieve full serialization ? => field traits
# => raw content
# => segments
# => Sequence => serialization possible ? => or at least caching of the fields that requires construction => field traits

use strict;
use warnings;

use Text::Trim;

use Moose;
use namespace::autoclean;

extends( 'Modality::SingleStringSequenceModality' );

# CURRENT : custom / serialized (using a trait ?) utterance serialization for this Modality ?

sub _sequence_class_builder {
    return 'Web::Summarizer::Sentence';
}

# CURRENT : we're losing POS information here ? => if the modality is fluent expect POS
# CURRENT : what if generate the chunked version of the summary here ?
sub data_generator {
    my $this = shift;

    my $raw_summary = $this->object->get_field( 'summary' , namespace => 'dmoz' );

    # TODO : segment raw summary into individual sentences => how ?

    return [ $raw_summary ];
}

#TODO : to be removed ? => custom preparation of summaries
sub _segments_builder {

    my $this = shift;
    my $segments = $this->get_data;

    # => run chunking at this point => one segment per identified sentence ?

    my @filtered_segments = map {

	my $raw_summary = $_;
	my $corrected_summary = $raw_summary;

	# 1 - remove anything that's withing parentheses
	if ( $corrected_summary =~ s/[\[\(][^\]\)]+[\]\)]//sg ) {
	    $this->logger->info( "Corrected original summary: $raw_summary => $corrected_summary" );
	}

	trim( $corrected_summary );

    } @{ $segments };

    return \@filtered_segments;

}

with( 'Modality' => { fluent => 1 , namespace => 'dmoz' , id => 'summary' } );

__PACKAGE__->meta->make_immutable;

1;
