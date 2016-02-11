package Web::Extractor::ReferenceSentencesExtractor;

# TODO : no-op for now, ultimately should be responsible for calling the retrieval module.

use strict;
use warnings;

use Moose::Role;
#use namespace::autoclean;

sub extract_sentences {

    my $this = shift;
    my $instance = shift;

    # TODO : this can only be temporary
    my $references = shift;

    return $references;

}

with('Web::Extractor::SentenceExtractor');

#__PACKAGE__->meta->make_immutable;

1;
