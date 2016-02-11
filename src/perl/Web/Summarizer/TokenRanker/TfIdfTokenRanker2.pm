package Web::Summarizer::TokenRanker::TfIdfTokenRanker2;

use strict;
use warnings;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

with( 'DMOZ' );
with( 'Web::UrlData::Processor' );

sub filter {
    my $this = shift;
    my $token = shift;
    return 1;
}

method weighter ( :$source , :$token , :$utterance , :$utterance_prior ) {
    return ( 1 / $utterance->length ) / ( 1 + $self->global_data->global_count( 'summary' , 1 , lc( $token ) ) );
}

with( 'Web::Summarizer::TokenRanker' );

__PACKAGE__->meta->make_immutable;

1;
