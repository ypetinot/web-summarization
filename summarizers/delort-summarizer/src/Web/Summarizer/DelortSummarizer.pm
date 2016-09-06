package Web::Summarizer::DelortSummarizer;

# reimplementation of the context-based summarizers described in \cite{Delort2003}

use strict;
use warnings;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON;
use URI;
use URI::URL;
use Encode;
use File::Path;
use File::Temp qw/tempfile/;
use XML::Generator escape => 'always';
use XML::TreePP;
use Lingua::EN::Sentence qw( get_sentences add_acronyms set_EOS );
use Text::Trim;

use Clusterer::Hierarchical;
use HTMLRenderer::LynxRenderer;
use Similarity;
use String::Tokenizer;

use Moose;
use namespace::autoclean;

# TODO ?
#with( 'Web::Summarizer::SentenceSummarizer' => { sentence_source => 'context' } );
with( 'Web::Summarizer' );

# values used in \cite{Delort2003}
has 'context_hierarchical_clustering_mode' => ( is => 'ro' , isa => 'Str' , default => 'all-links' );
has 'context_hierarchical_clustering_threshold' => ( is => 'ro' , isa => 'Num' , default => 0.2 );

# max sentences (used ?)
has 'max_sentences' => ( is => 'ro' , isa => 'Num' , default => 1 );

# max words (used ?)
has 'max_words' => ( is => 'ro' , isa => 'Num' , default => 0 );

# id
has 'id' => ( is => 'ro' , isa => 'Str' , default => "delort" );

# tokenizer
# TODO : should be the tokenizer of the instance object ?
has '_tokenizer' => ( is => 'ro' , isa => 'String::Tokenizer' , init_arg => undef , lazy => 1 , builder => '_tokenizer_builder' );
sub _tokenizer_builder {
    return String::Tokenizer->new;
}

sub summarize {
    
    my $this = shift;
    my $instance = shift;

    # only used by oracle mode
    my $true_summary = $instance->summary_modality->content;

    my @summaries;
    
    # generate "rendered" content
=pod
    my $rendered_content = "";
    if ( $content ) {
	my $rendered_content_raw = HTMLRenderer::LynxRenderer->render( $content );
	if ( $rendered_content_raw ) {
	    my @raw_sentences = map { trim $_; } split /\n+|[[:cntrl:]]+/, $rendered_content_raw;
	    $rendered_content = join(" ", @raw_sentences);
	}
    }
=cut
    my $rendered_content = $instance->content_modality->content;

    # TODO : add filtering ?

    my @content_sentences = grep { length($_); } @{ $instance->content_modality->segments };
    my $size_content = scalar( @content_sentences );
    
    # 0 - collect context sentences
=pod
    my $anchortext_data = decode_json( $anchortext );
    my @context_sentences = grep { length($_); } map { @{ $_->{'sentence'} } } grep { defined( $_->{'sentence'} ) } @{ $anchortext_data };
=cut
    my @context_sentences = grep { length($_); } @{ $instance->anchortext_modality->segments };
    my $size_context = scalar( @context_sentences );

    # CURRENT : override mode ?
    ###my $mode = $this->system;
    my $mode = undef;

    # *******************************************************************************************************************************
    # Note : this is the code version of Table in \cite{Delort2003}
    # Note : Delort's experiment was targeting specifically pages that do have context. Since our data has pages that do not have context, we default to the internal method when the context size is zero.

    my $size_content_threshold = 3;
    my $size_context_threshold = 4;
    if ( ( ! $size_context ) || ( $size_content <= $size_content_threshold ) ) {
	
	if ( $size_context <= $size_context_threshold ) {
	    $mode = 'delort-internal';
	}
	else {
	    $mode = 'delort-context';
	}

    }
    else {

	$mode = 'delort-mixed';

    }

    $this->logger->info( "Delort summarizer : $size_content / $size_context => $mode" );

    # *******************************************************************************************************************************

    # Note : oracle no longer makes sense ?
    my $do_oracle = 0;
    if ( $mode =~ m/delort-oracle$/ ) {
	$do_oracle = 1;
    }
    
    my $do_mixed = ( $mode =~ m/delort-mixed$/ || $do_oracle );
    my $do_context = ( $mode =~ m/delort-context$/ || $do_oracle );
    my $do_internal = ( $mode =~ m/delort-internal$/ || $do_oracle );
    
    if ( !$do_mixed && !$do_context && !$do_internal ) {
	die "System ($mode) is not supported ...";
    }
    
    if( $do_mixed ) {
	
	# \cite{Delort2003} / Algorithm 1
	
	# 1 - "compute the degree of topicality of each (context) sentence with the target document"
	my %index2topicality;
	my @context_sentences_indices;
	for (my $i=0; $i<scalar(@context_sentences); $i++) {
	    $index2topicality{ $i } = $this->_compute_topicality( $context_sentences[ $i ] , $rendered_content );
	    push @context_sentences_indices, $i;
	}
	
	# 2 - "rank the results with respect to these values"
	my @sorted_context_sentences_indices = sort { $index2topicality{ $b } <=> $index2topicality{ $a } } @context_sentences_indices;
	
	# 3 - "select the sentences having the best topicality values for the summary"
	if ( $this->max_sentences() && scalar( @sorted_context_sentences_indices ) > $this->max_sentences() ) {
	    splice @sorted_context_sentences_indices, $this->max_sentences();
	}
	
	push @summaries, join(" ", map { $context_sentences[ $_ ]; } @sorted_context_sentences_indices);
	
    }
    
    if( $do_context ) {
	
	# \cite{Delort2003} / Algorithm 2
	
	# 1/2/3/4 - perform hierarchical clustering on the set of context sentences
	my $hierarchical_clusterer = new Clusterer::Hierarchical( mode => 'all-links' , similarity_threshold => $this->context_hierarchical_clustering_threshold , 
								  similarity_measure => \&Similarity::_compute_cosine_similarity );
	my ($context_sentences_clusters,$context_sentences_clusters_stats) = $hierarchical_clusterer->cluster( \@context_sentences );
	
	# 5 - Remove all the one-sized clusters
	my @filtered_context_sentences_clusters = grep { scalar( @{ $_ } ) > 1 } @{ $context_sentences_clusters };
	
	# 6 - Rank clusters by decreasing cardinality
	my @ranked_context_sentences_clusters = sort { scalar( @{ $b } ) <=> scalar( @{ $a } ) } @filtered_context_sentences_clusters;
	
	# 7/8 - Apply internal ranking function and selected top ranking sentence from each cluster
	my @selected_context_sentences;
	while ( scalar(@ranked_context_sentences_clusters) && ( scalar(@selected_context_sentences) < $this->max_sentences() ) ) {
	    
	    my $current_cluster = shift @ranked_context_sentences_clusters;
	    my $sorted_cluster = $this->_algorithm_2_cluster_ranking( $current_cluster );
	    
	    push @selected_context_sentences, $sorted_cluster->[0];
	    
	}
	
	push @summaries, join(" ", @selected_context_sentences);
	
    }

    if ( $do_internal ) {

	# Compute for each sentence of the content its similarity to the whole content
	# TODO : introduce sentence objects ?
	my @scored_content_sentences = map { [ $_ , Similarity::_compute_cosine_similarity( $rendered_content , $_ ) ] } @content_sentences;
	my @sorted_content_sentences = map { $_->[ 0 ] } sort { $b->[ 1 ] <=> $a->[ 1 ] } @scored_content_sentences;

	# TODO : how to reduce code duplication with do_mixed ?
	
	# Note : select the sentences having the highest similarity with the whole content
	if ( $this->max_sentences && scalar( @sorted_content_sentences ) > $this->max_sentences ) {
	    splice @sorted_content_sentences, $this->max_sentences;
	}
	
	push @summaries, join( " ", @sorted_content_sentences );

    }
    
    my $summary = "";
    my $n_generated_summaries = scalar(@summaries);
    if ( $do_oracle && $true_summary && $n_generated_summaries > 1 ) {
	
	# we're returning the oracle summary (we're using an oracle here)
	
	my @mapped_summaries = map { [ $_ , Similarity::_compute_cosine_similarity( $true_summary , $_ ) ] } @summaries;
	@summaries = map { $_->[ 0 ] } sort { $b->[ 1 ] <=> $a->[ 1 ] } @mapped_summaries;
	
    }
    
    $summary = $summaries[ 0 ];

    # turn summary into an object
    my $summary_object = new Web::Summarizer::Sentence( raw_string => $summary , source_id => __PACKAGE__ , object => $instance );

    return $summary_object;

}

# *************************** Supporting functions ***************************

my %vectorization_cache;
sub _vectorize {

    my $this = shift;
    my $string = shift;

    # check cache
    my $string_hash = md5_hex( encode_utf8( $string ) );
    if ( defined( $vectorization_cache{ $string_hash } ) ) {
	return $vectorization_cache{ $string_hash };
    }

    # vectorize string
    my $vectorized_string = $this->_tokenizer->vectorize( $string );

    # update cache
    $vectorization_cache{ $string_hash } = $vectorized_string;

    return $vectorized_string;

}

# Note: the definition of topicality in \cite{Delort2003} is ambiguous
sub _compute_topicality {

    my $this = shift;
    my $string = shift;
    my $reference_content = shift;

    # vectorize string
    my $vectorized_string = $this->_vectorize( $string );

    # vectorize reference content
    my $vectorized_reference_string = $this->_vectorize( $reference_content );
    
    # compute intersection (dot product ?)
    my %intersection;
    map { $intersection{ $_ } = ( $vectorized_reference_string->{ $_ } || 0 ) * $vectorized_string->{ $_ } ; } keys( %{ $vectorized_string } );
    
    # compute topicality
    my $intersection_norm = _norm( \%intersection );
    my $reference_norm = _norm( $vectorized_reference_string );
    my $topicality = ( $reference_norm ) ? ( $intersection_norm / $reference_norm ) : 0;

    return $topicality;
    
}

# computes the norm of a vector (should we move this to a Vector class ?)
sub _norm {

    my $vector = shift;

    my $sum = 0;
    map { $sum += $vector->{ $_ } ** 2 } keys( %{ $vector } );

    return sqrt( $sum );

}

# cluster ranking function for Algorithm 2 (context)
sub _algorithm_2_cluster_ranking {

    my $this = shift;
    my $cluster = shift;

    # compute cluster centroid
    my @vectorized_sentences = map { $this->_tokenizer->vectorize( $_ ); } @{ $cluster };
    my $centroid = Similarity::compute_centroid( \@vectorized_sentences );
    
    my %index2length;
    my %index2centroid_distance;
    for (my $i=0; $i<scalar(@vectorized_sentences); $i++) {
	
	my $current_sentence_vector = $vectorized_sentences[ $i ];

	$index2length{ $i } = $current_sentence_vector->manhattan_norm();
	$index2centroid_distance{ $i } = $centroid->clone()->substract( $current_sentence_vector )->norm();

    }

    # 1 - rank cluster by decreasing length
    my %R1; my $r1_cursor = 0;
    map { $R1{ $_ } = $r1_cursor++; } sort { $index2length{$b} <=> $index2length{$a} } keys( %index2length );

    # 2 - rank cluster by decreasing proximity to centroid
    my %R2; my $r2_cursor = 0;
    map { $R2{ $_ } = $r2_cursor++; } sort { $index2centroid_distance{ $a } <=> $index2centroid_distance{ $b } } keys( %index2centroid_distance );

    # 3 - map each sentence to its score
    my %f;
    map { $f{ $_ } = $R1{ $_ } * sqrt( $R2{ $_ } ) } keys( %index2length );

    # rank cluster
    my @ranked_cluster = map { $cluster->[ $_ ]; } sort { $f{ $a } <=> $f{ $b } } keys( %f );

    return \@ranked_cluster;

}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=head1 NAME
    
    delort-summarizer - Re-implementation of Delort's context-based summarization algorithms
    
=head1 SYNOPSIS
    
    run-summarizer [options]

    Options:
       --help            brief help message
       --man             full documentation
       --system          context extraction mode

=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>

    Prints the manual page and exits.

=back

=head1 DESCRIPTION

    Re-implement the two context-based Web summarization algorithms proposed by Delort et al. in \cite{Delort2003}.

=cut

1;
