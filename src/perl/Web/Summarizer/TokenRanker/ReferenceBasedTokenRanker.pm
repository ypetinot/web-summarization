package Web::Summarizer::TokenRanker::ReferenceBasedTokenRanker;

# TODO : doesn't belong under Web::Summarizer, maybe Web::TokenRanker::ReferenceBasedTokenRanker ?

use strict;
use warnings;

use Function::Parameters qw(:strict);

use Moose;
use namespace::autoclean;

extends( 'Web::Summarizer::TokenRanker' );
with( 'Web::UrlData::Processor' );

has 'reference_object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

sub filter {
    my $this = shift;
    my $token = shift;
    return ( ! $token->object_support( $this->reference_object ) );
}

method weighter ( :$source , :$token , :$utterance , :$utterance_prior ) {
    return $utterance_prior;
}

__PACKAGE__->meta->make_immutable;

1;
