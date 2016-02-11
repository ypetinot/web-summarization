package Service::NLP::Word2Vec;

use strict;
use warnings;

use Word2Vec::Word2Vec;

use Memoize;

use Moose;
use namespace::autoclean;

with( 'Logger' );
with( 'Service::ThriftBased' => { port => 9090 , client_class => 'Word2Vec::Word2VecClient' , use_framed_transport => 0 } );

# TODO : is this the best place to perform caching ?
memoize( 'analogy' );
sub analogy {
    my $this = shift;

    my $response = $this->_client->analogy( @_ );

    # TODO : should we preserve the original data structure ? the only issue is that it is auto-generated and thus not in my control ~
    my @analogies = map { [ $this->_clean_string( $_->word ) , $_->score ] } @{ $response };

    return \@analogies;
}

sub distance {
    my $this = shift;
    return $this->_client->distance( @_ );
}

# CURRENT : comparison of multi-term phrases => assume compositionality
#           => should be handled by service
memoize( 'cosine_similarity' );
sub cosine_similarity {

    my $this = shift;

    # Note : word2vec does not handle numerical values
    if ( $_[ 0 ] =~ m/^\d+/ || $_[ 1 ] =~ m/^\d+/ ) {
	return 0;
    }

    # TODO : there might be a problem with not relinquishing the client/socket objects
    my $client = Service::NLP::Word2Vec->new->_client;
    #my $client = $this->_client;
    my $similarity = $client->cosine_similarity( @_ );

    $this->logger->trace( "Requested cosine similarity for : " . join( " / " , @_ ) . " => $similarity" );
    return $similarity;

}

sub neighbors {

}

sub _clean_string {
    my $this = shift;
    my $raw_string = shift;
    # TODO : implement using e.g. tr ?
    my @string_segments = split /_/ , $raw_string;
    my $clean_string = join( " " , @string_segments );
    return $clean_string;
}

__PACKAGE__->meta->make_immutable;

1;
