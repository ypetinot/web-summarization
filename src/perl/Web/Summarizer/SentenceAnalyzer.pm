package Web::Summarizer::SentenceAnalyzer;

# TODO: abstract this class into a SequenceAnalyzer class ?

use strict;
use warnings;

# Computes various metrics comparing two summaries
# Works off non-tokenized strings ...

use List::Util qw/min/;

use DMOZ::GlobalData;
use DMOZ::Weighter;
use Similarity;
use Vocabulary;
use Web::Summarizer::Sentence;

use Moose;
use namespace::autoclean;
with( 'DMOZ' );
with( 'Logger' );

# data cache
has '_data_cache' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

=pod
# TODO : rename Service::Web::UrlData to something that only evoke DMOZ::GlobalData
has 'remote_service_client' => ( is => 'ro' , isa => 'Service::Web::UrlData' , init_arg => undef , lazy => 1 ,
				 builder => '_remote_service_client_builder' );
=cut

with( 'DMOZ::Weighter' => { field => 'summary' } );

sub analyze {

    my $this = shift;
    my $sentence_1 = shift; # reference
    my $sentence_2 = shift;

    my ( $sentence_1_new , $sentence_2_new ) = map {
	# StringSequence so we don't have to worry about advanced tokenization aspects
	new Web::Summarizer::StringSequence( object => $_->object , raw_string => $_->raw_string , source_id => $_->source_id );
    } ( $sentence_1 , $sentence_2 );
    
    my @results;

    # 1 - generate bare (punctuation and marker free) versions of both sentences
    my $token_filter = sub { my $a = shift; return ( ! $a->is_punctuation && ! $a->is_special ); };
    my ( $sentence_1_new_bare , $sentence_2_new_bare ) = map { $_->filter( $token_filter ) } ( $sentence_1_new , $sentence_2_new );

    # 2 - iterate through requested metrics
    # TODO: turn metrics into individual classes
    my @metrics = (
	[ 'ngram-prf' , \&compute_ngram_prf , [ 1 , 3 , 1 ] , 1 ],
	[ 'normalized-lcs' , \&compute_normalized_lcs , [] , 1 ],
# CURRENT : add metric based on Weiwei's similarity model
#	[ 'wtmf' , \&compute_wtmf , [] , 1 ],
###	[ 'ngram-jaccard' , \&compute_ngram_jaccard , [ 1 , 0 ] , 1 ],
###	[ 'ngram-jaccard' , \&compute_ngram_jaccard , [ 2 , 0 ] , 1 ],
###	[ 'ngram-jaccard' , \&compute_ngram_jaccard , [ 3 , 0 ] , 1 ],
###	[ 'ngram-jaccard-weighted' , \&compute_ngram_jaccard , [ 1 , 1 ] , 1 ],
###	[ 'ngram-jaccard-weighted' , \&compute_ngram_jaccard , [ 2 , 1 ] , 1 ],
###	[ 'ngram-jaccard-weighted' , \&compute_ngram_jaccard , [ 3 , 1 ] , 1 ],
#       [ 'rouge' , \&compute_rouge , [] , 1 ]
#       [ 'dependencies-prf' , \&compute_dependencies_prf , [ 'stanford'] , 1 ]
	);

    foreach my $metric (@metrics) {
	
	my $metric_id = $metric->[ 0 ];
	my $metric_op = $metric->[ 1 ];
	my @metric_args = @{ $metric->[ 2 ] };
	my $metric_use_bare = $metric->[ 3 ];
	
	my $metric_data = $metric_use_bare ?
	    $this->$metric_op( $sentence_1_new_bare , $sentence_2_new_bare , @metric_args ) :
	    $this->$metric_op( $sentence_1_new , $sentence_2_new , @metric_args );

	# TODO : turn this into a simple map ?
	for (my $i=0; $i<scalar( @{ $metric_data } ); $i++) {

	    my $local_id = $metric_data->[ $i ]->[ 0 ];

	    # TODO : can we avoid code redundancy ?
	    my $metric_key = defined( $local_id ) ? join( "-" , $metric_id , $local_id ) : $metric_id;
	    
	    my $metric_value = $metric_data->[ $i ]->[ 1 ];
	    
	    if ( $metric_value > 1 ) {
		$this->warn( "Dubious metric value for $metric_key : $metric_value" );
	    }

	    push @results , [ $metric_key , $metric_value ];

	}

    }

    return \@results;

}

# TODO : reference comes second ?
sub compute_normalized_lcs {

    my $this = shift;
    my $sentence_1 = shift;
    my $sentence_2 = shift;

    my @results;

# TODO : to be removed
=pod
    # TODO : this (the sequence generation) should probably be moved to a more generic class ?
    #        => could be part of the StringSequence class so that the 
    my @sentence_1_sequence = split /\s+/ , join( ' ' , map { $_->surface_regular } grep { ! $_->is_punctuation } @{ $sentence_1->object_sequence } );
    my @sentence_2_sequence = split /\s+/ , join( ' ' , map { $_->surface_regular } grep { ! $_->is_punctuation } @{ $sentence_2->object_sequence } );

    push @results , [ undef , Similarity->lcs_similarity( \@sentence_1_sequence , \@sentence_2_sequence ) ];
=cut    

    push @results , [ undef , $sentence_1->lcs_similarity( $sentence_2 , normalize => 1 , keep_punctuation => 0 ) ];

    return \@results;

}

# sentence_1 is the reference
sub compute_ngram_prf {

    my $this = shift;
    my $sentence_1 = shift;
    my $sentence_2 = shift;
    my $ngram_order_from = shift;
    my $ngram_order_to = shift;
    my $weighted = shift;

    my @results;
    for ( my $ngram_order = $ngram_order_from; $ngram_order <= $ngram_order_to; $ngram_order++ ) {
	
	for ( my $weighted_mode = 0; $weighted_mode <= $weighted; $weighted_mode++ ) {
	    
	    my @param_context = ( $ngram_order , $weighted_mode );
	    
	    my $sentence_1_ngrams = $sentence_1->get_ngrams( $ngram_order ,
							     return_vector => 1 ,
							     weight_callback => ( $weighted_mode ? $this->weighter : undef ) ,
							     surface_only => 1 ,
							     normalize => 1 );
	    my $sentence_2_ngrams = $sentence_2->get_ngrams( $ngram_order ,
							     return_vector => 1 ,
							     weight_callback => ( $weighted_mode ? $this->weighter : undef ) ,
							     surface_only => 1 ,
							     normalize => 1 );
	    
	    my ( $precision , $recall , $fmeasure ) = $this->prf( $sentence_1_ngrams , $sentence_2_ngrams );
	    
	    push @results , [ $this->_key_creator( 'precision' , @param_context ) , $precision ];
	    push @results , [ $this->_key_creator( 'recall' , @param_context ) , $recall ];
	    push @results , [ $this->_key_creator( 'fmeasure' , @param_context ) , $fmeasure ];
	    
	}
	
    }

    return \@results;

}

# CURRENT : weighted prf ? weighted accuracy ?
# Each term can be assigned a weight ( its idf ), with the default weight being 1 - use the DMOZ vocabulary as a source of idf

# precision/recall/f-measure computation
sub prf {

    my $this = shift;
    my $set_1 = shift; #reference
    my $set_2 = shift;

    # 1 - contingency table
    my $n_set_1 = $set_1->manhattan_norm;
    my $n_set_2 = $set_2->manhattan_norm;
    my $n_overlap = 0;
    map { $n_overlap += min( $set_1->coordinates->{ $_ } || 0 , $set_2->coordinates->{ $_ } || 0 ); } keys( %{ $set_1->coordinates } );

    # 2 - P/R
    my $p = $n_set_2 ? ( $n_overlap / ( $n_set_2 ) ) : 1;
    my $r = $n_set_1 ? ( $n_overlap / ( $n_set_1 ) ) : 1;

    # 3 - F-Measure
    my $denominator = $p + $r;
    my $f1 = $denominator ? 2 * ( $p * $r ) / ( $p + $r ) : 0;

    return ( $p , $r , $f1 );
    
}

sub compute_ngram_coverage {

    my $this = shift;
    my $target_sequence = shift;
    my $path = shift;

    my @coverage;

    # TODO : should we do this in one pass ?
    for (my $ngram_order=1; $ngram_order<=$this->ngram_order_max; $ngram_order++) {

	# 1 - compute n-grams for target sequence
	my $target_ngrams = $target_sequence->get_ngrams( $ngram_order , 1 , undef , 1 , normalize => 1 );

	# 2 - compute n-grams for path
	my $path_sentence_object = new Web::Summarizer::Sentence( token_sequence => $path , string => '__irrelevant__' );
	my $path_ngrams = $path_sentence_object->get_ngrams( $ngram_order , 1 , undef , 1 , normalize => 1 );
	
	my %difference;
	map { $difference{ $_ } = ( $target_ngrams->{ $_ } || 0 )  * ( $path_ngrams->{ $_ } || 0 ) } uniq ( keys( %{ $path_ngrams } ) , keys( %{ $target_ngrams } ) );

	push @coverage, \%difference;

    }

    return \@coverage;

}

sub compute_ngram_jaccard {

    my $this = shift;
    my $sentence_1 = shift;
    my $sentence_2 = shift;
    my $ngram_order = shift;
    my $weighter = shift;
    
    my $sentence_1_ngrams = $sentence_1->get_ngrams( $ngram_order , 1 , ( $weighter ? $this->weighter : undef ) , 1 , normalize => 1 );
    my $sentence_2_ngrams = $sentence_2->get_ngrams( $ngram_order , 1 , ( $weighter ? $this->weighter : undef ) , 1 , normalize => 1 );

    my $jaccard = Vector::jaccard( $sentence_1_ngrams , $sentence_2_ngrams );

    my $result = { 'jaccard' => $jaccard };
    
    return $result;

}

sub compute_dependencies_prf {

    my $this = shift;
    my $sentence_1 = shift; # reference
    my $sentence_2 = shift;
    my $mode = shift;

    # 1 - get dependencies for both sentences
    my $sentence_1_dependencies = $sentence_1->get_dependencies();
    my $sentence_2_dependencies = $sentence_2->get_dependencies();

    # 2 - compute P/R/F1 with respect to the reference sentence
    # TODO : does prf really support dependencies ?
    my ( $precision , $recall , $fmeasure ) = $this->prf( $sentence_1_dependencies , $sentence_2_dependencies );
    
    my %results;
    $results{ 'precision' } = $precision;
    $results{ 'recall' } = $recall;
    $results{ 'fmeasure' } = $fmeasure;
    
    return \%results;

}

# sentence_1 is the reference
sub compute_rouge {

    my $this = shift;
    my $sentence_1 = shift;
    my $sentence_2 = shift;

    # TODO - right now unable to achieve proper integration

}

sub _key_creator {
    my $this = shift;
    return join( "-" , @_ );
}

__PACKAGE__->meta->make_immutable;

1;
