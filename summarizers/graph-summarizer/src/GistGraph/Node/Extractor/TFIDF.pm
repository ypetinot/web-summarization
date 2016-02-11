package GistGraph::Node::Extractor::TFIDF;

# Baseline - TFDIF - extractor

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use Similarity;

extends 'GistGraph::Node::Extractor';

with Storage('format' => 'JSON', 'io' => 'File');

# fields
has 'df' => (is => 'ro', isa => 'HashRef', init_arg => undef, builder => '_generate_idf');

# generate idf from training data
sub _generate_idf {
    
    my $this = shift;

    my %global_df;

    foreach my $document (@{ $this->url_data() }) {
	my $document_tfs = $this->_compute_document_tfs( $document );
	map { $global_df{$_}++; } keys( %{ $document_tfs } );
    }
    

    return \%global_df;

}

# extraction method
sub extract {

    my $this = shift;
    my $document = shift;
    
    # map document to tfs
    my $document_tfs = $this->_compute_document_tfs( $document );
    
    # compute tfidf score for all tokens in document
    my %tfidfs;
    map { $tfidfs{ $_ } = ( $document_tfs->{ $_ } || 0 ) / ( $this->df()->{ $_ } || 1 ); } keys( %{ $document_tfs } );

    # sort tokens by decreasing tfidf score
    my @sorted_tokens = sort { $tfidfs{ $a } <=> $tfidfs{ $b } } keys( %tfidfs );

    my $selected_token = undef;
    if ( scalar(@sorted_tokens) ) {
	$selected_token = $sorted_tokens[0];
    }

    return $selected_token;

}

# compute tfs for a document
sub _compute_document_tfs {

    my $this = shift;
    my $document = shift;

    # we're working of preparsed content ? --> yes
    my $prepared_content = $document->fields()->{ 'content::prepared' };
    
    my %tfs;
    map { $tfs{ $_ }++; } @{ $prepared_content };
    
    return \%tfs;

}

no Moose;

1;
