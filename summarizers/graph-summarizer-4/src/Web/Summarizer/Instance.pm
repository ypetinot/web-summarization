package Web::Summarizer::Instance;

use strict;
use warnings;

use Moose::Role;

# raw input object
has '+raw_input_object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# raw output object (if known)
has '+raw_output_object' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 0 );

1;
