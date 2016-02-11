package WWW::Summarization::URLEntity;

use strict;
use warnings;

# abstracts the notion of a URL Entity that can map to real-world Entity

use base qw(WWW::Summarization::Entity);

# 3 - remove/abstract all entities and chunks from all the elements of TARGET_CONTEXT
# for each element of context, match each representation of the target entity against it
# while ignoring spaces, punctuation and case, based on the equivalence rules for URLs.
foreach my $facet (@context_facets) {

    my $context_string = $context_element->text($facet);

    foreach my $representation ($context->getTargetRepresentations()) {

	my $filler = '[[:punct:]]*\s*';
	my @representation_characters = split //, $representation;
	my @representation_regex_tokens;
	foreach my $representation_character (@representation_characters) {
	    push @representation_regex_tokens, $representation_character;
	    push @representation_regex_tokens, $filler;q
	    }

	my $representation_regex = join('', @representation_regex_tokens);
	$representation_regex=qr/$representation_regex/si;

	$context_string =~ s/$representation_regex/[\@\@TARGET_ENTITY\@\@]/g;

    }



1;
