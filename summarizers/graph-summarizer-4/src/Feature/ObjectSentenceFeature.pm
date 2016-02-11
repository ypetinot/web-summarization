package Feature::ObjectSentenceFeature;

use strict;
use warnings;

use Moose::Role;

with('Feature');

=pod
# object
has 'object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# sentence
has 'sentence' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 1 );
=cut

1;
