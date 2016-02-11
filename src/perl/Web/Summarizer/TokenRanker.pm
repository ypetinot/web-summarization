package Web::Summarizer::TokenRanker;

use strict;
use warnings;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

method generate_ranking( $object , :$count_threshold = 0 , :$modality_threshold = 0 , :$return_score = 0 )  {

    my $utterances_sets = $object->utterances;

    my %tokenId2weight;
    my %tokenId2token;
    my %tokenId2count;
    foreach my $source_id (@{ $self->alignment_sources }) {
	
	# 1 - get utterances for the current source
	# TODO : could we do better than defaulting to a empty array ?
	my @utterances = @{ $utterances_sets->{ $source_id } || [] };

	# 2 - update local weight of individual tokens
	my $n_utterances = $#utterances + 1;
	if ( $n_utterances ) {

	    # TODO : shouldn't this be computed by weighter ? 
	    my $utterance_prior = 1 / $n_utterances;
	    foreach my $utterance (@utterances) {
		map {
		    my $token = $_;
		    my $token_id = $_->id;
		    $tokenId2token{ $token_id } = $token;
		    $tokenId2weight{ $token_id } += $self->weighter( token => $_->surface , source => $source_id , utterance => $utterance , utterance_prior => $utterance_prior );
		    $tokenId2count{ $token_id }++;
		} grep {
		    $self->filter( $_ );
		} @{ $utterance->object_sequence };
	    }
	    
	}
	
    }

    my @ranked_token_ids = grep { !$count_threshold || ( $tokenId2count{ $_ } >= $count_threshold ) } sort { $tokenId2weight{ $b } <=> $tokenId2weight{ $a } } keys( %tokenId2weight );


    if ( $return_score ) {
	my @scored_tokens = map { [ $tokenId2token{ $_ } , $tokenId2weight{ $_ } ] } @ranked_token_ids;
	return \@scored_tokens;
    }
    
    my @ranked_tokens = map { $tokenId2token{ $_ }; } @ranked_token_ids;
    return \@ranked_tokens;

}

with( 'Web::UrlData::Processor' );

__PACKAGE__->meta->make_immutable;

1;
