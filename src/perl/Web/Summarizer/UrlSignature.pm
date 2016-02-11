package Web::Summarizer::UrlSignature;

# Implements the concept of signature for a Web page/URL.

use strict;
use warnings;

use Web::Summarizer::TokenRanker::UtteranceLengthTokenRanker;

use List::MoreUtils qw/uniq/;
use Statistics::Basic qw(:all);

# TODO : implement as a role ?
use Moose;
use namespace::autoclean;

with( 'DMOZ' );
with( 'Logger' );

# TODO : to be removed
=pod
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , required => 1 );
=cut

has 'source_modalities' => ( is => 'ro' , isa => 'ArrayRef[Str]' , default => sub {
    # Note : ok since specific terms in the title would have to be filtered based on URL matching ?
    [ 'content' , 'title' ]
# We only use the content as a source of signature terms
# the title is short by nature and thus prone to bringing up specific terms
# the url, and in particular its domain name, is also fundamentally (and by definition !) page-specific 
#    [ 'title' , 'url' ]
			     } );
has 'boosting_modalities' => ( is => 'ro' , isa => 'ArrayRef[Str]' , default => sub {
    [ 'url' , 'title' , 'anchortext' ]
#    [ 'content' , 'anchortext' ]
			       } );

# CURRENT : anonymization
sub anonymize {

    my $this = shift;
    my $utterances = shift;

    # 1 - get URL domain
    my $domain = $this->url->get_domain;
    
    # 2 - LCS between domain name and every content utterance
    my @utterances_anonymized = map {
	# if LCS covers the full domain => maps sequence of complete tokens to abstract marker
	$_;
    } @{ $utterances };

    return \@utterances_anonymized;

}

# CURRENT : implement signature using a TermRanker ?
sub compute {

    my $this = shift;
    my $object = shift;

    my %coordinates;

    # TODO : we shouldn't have to go through _html_document => improve this
    my $url_host = $object->_html_document->url->host;

=pod
    # 1 - collect utterances from each source modality
    foreach my $source_modality ( @{ $this->source_modalities } ) {

	my $source_utterances = $object->utterances->{ $source_modality };
	foreach my $source_utterance (@{ $source_utterances }) {
	    
	    # TODO : apply normalization here
	    
	    # content utterance length
	    # TODO : go into log space ?
	    my $source_utterance_length = $source_utterance->length;
	    my $source_utterance_per_word_weight = 1 / $source_utterance_length;
	    
	    # iterate over individual words in utterance
	    for (my $i=0; $i<$source_utterance_length; $i++) {
		my $source_utterance_word_surface = $source_utterance->get_element( $i )->surface;
		$coordinates{ lc( $source_utterance_word_surface ) } += $source_utterance_per_word_weight;
	    }
	    
	}

    }
=cut
    my $token_ranker = new Web::Summarizer::TokenRanker::UtteranceLengthTokenRanker( alignment_sources => $this->source_modalities );

    # TODO : only consider terms that appear in at least 2 modalities => confidence on term relevance (maybe can be weighted to smooth things out) ?
    my $ranked_tokens = $token_ranker->generate_ranking( $object , count_threshold => 2 , return_score => 1 );
    my $n_tokens = scalar(@{ $ranked_tokens });
    for (my $i=0; $i<$n_tokens; $i++) {

	my $ranked_token_entry = $ranked_tokens->[ $i ];
	my $ranked_token = $ranked_token_entry->[ 0 ];
	my $ranked_token_score = $ranked_token_entry->[ 1 ];

	if ( $ranked_token->is_punctuation ) {
	    next;
	}
	
	my $ranked_token_regex = $ranked_token->as_regex_anywhere;

	if (
	    $ranked_token->length < 3  # Note : is this arbitrary ?
	    || $ranked_token->is_numeric
	    || ( $url_host =~ m/$ranked_token_regex/i )
	    )
	    {
		$this->logger->info( "Anonymization - ignoring " . $ranked_token->surface );
	    next;
	}

	$coordinates{ $ranked_token->id } = $n_tokens - $i;
	#$coordinates{ $ranked_token->id } = $ranked_token_score;

    }

    # 2 - boosting - url / title / anchortext
    # TODO : assign different weights to each modality ?
    # TODO : higher boost for links / removed links maybe ? (i.e. this strongly associates this word to this page)
    my %coordinates_boost;
    foreach my $boosting_modality ( @{ $this->boosting_modalities } ) {

	# TODO : get utterance as vector ?
	# TODO : vectorized operations ?

	my $boosting_modality_object = $object->modalities->{ $boosting_modality };
	foreach my $term (keys( %coordinates )) {
	    if ( $boosting_modality_object->supports( $term ) ) {
###		$coordinates_boost{ $term }++;
	    }
	}

# TODO : to be removed
=pod
	my $boosting_modality_utterances = $object->utterances->{ $boosting_modality };
	foreach my $boosting_modality_utterance (@{ $boosting_modality_utterances }) {

	    my $boosting_modality_utterance_length = $boosting_modality_utterance->length;
	    
	    # Note : we don't care so much about length here
	    for (my $i=0; $i<$boosting_modality_utterance_length; $i++) {
		my $boosting_modality_utterance_word_surface = $boosting_modality_utterance->get_element( $i )->surface;
		$coordinates_boost{ lc( $boosting_modality_utterance_word_surface ) }++;  
	    }

	}
=cut

    }

    # TODO : for each word, should we consider the weight of that word in the modality it originates from ?
    # TODO : no that this is the number of ngram occurrences, not the number of instances
    my $corpus_size = $this->global_data->global_count( 'summary' , 1 );

    # CURRENT : strategy
    # * to promote functional terms => weight individual terms based on the length of the utterances they appears in => stop words expected to appear in longer sentences
    #                               => can also artificially boost based on frequency in summary corpus but we would need to also dampen based on frequency in longer utterrances => weighted average ?
    #                               => score_occurrences *
    # => rank based on occurrences/length
    # => rank based on summary corpus
    # => multiply ? => frequent in modalities but infrequent in corpus => lower score /// infrequence in modalities but frequence in corpus => might still get a high score (unless i take the log ?)
    # learning problem => can compute word features, learn against search so that the gold summary is ranked as high as possible but maybe also other pages in the same category (category distance) => learn to retrieve => the query weights are the parameters that we want to learn, for each word appearing in the utterances !
    # * idf to demote infrequence terms ? or here again a weighted average would help ?

    # CURRENT : how do we implement this ?
    # 0 - for simplicity we're doing this outside of the search engine
    # 1 - can produce training pairs from the entire corpus (fully random pairing) or maybe more interesting by pairing urls at the category level (which is data that I have) => this means we would basically learn to optimize the LCS between the retrieved summary and the summary associated with the query (i.e. the target object)
    # 2 - or ? optimize based on position of ground truth ?
    # 3 - either way I can start by putting the overal pipeline in place ...
    
    # 3 - compute raw boosted coordinates
    my %signature_coordinates;
    my %term2corpus_count;
    map {
	my $term = $_;
	my $corpus_df_unnormalized = $this->global_data->global_count( 'summary' , 1 , $term ) || 0;
	my $corpus_df = $corpus_df_unnormalized / $corpus_size;
	my $coordinate_factor = 1 + ( $coordinates{ $term } || 0 );
	my $boost_factor = 1 + ( $coordinates_boost{ $term } || 0 );

	my $signature_coordinate = $coordinate_factor * $boost_factor / ( 1 + $corpus_df );
	#my $signature_coordinate = $coordinate_factor * $boost_factor * $corpus_df;

	$term2corpus_count{ $term } = $corpus_df_unnormalized;

	if ( $signature_coordinate ) {
	    $signature_coordinates{ $term } = $signature_coordinate;
	}
    }
    uniq ( keys( %coordinates ) , keys( %coordinates_boost ) );

=pod
    # compute count statistics
    # TODO : could consider a coocurrence graph and ignore pairs that never cooccur
    my @count_values = values( %term2corpus_count );
    my $count_mean = mean( @count_values );
    my $count_stddev = stddev( @count_values );

    # filter based on count statistics
    my %signature_coordinates_final;
    map {
	my $key = $_;
	my $key_count = $term2corpus_count{ $key };
	my $value = $signature_coordinates{ $key };
	if ( abs( $key_count - $count_mean ) <= 2 * $count_stddev ) {
	    $signature_coordinates_final{ $key } = $value;
	}
    } keys( %signature_coordinates );
=cut

    # instantiate vector object
    my $signature_vector = new Vector( coordinates => \%signature_coordinates );

    return $signature_vector;

}

__PACKAGE__->meta->make_immutable;

1;
