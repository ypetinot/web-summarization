package Web::KeyphraseExtractor;

# base class for all keyphrase extractors

use strict;
use warnings;

# TODO : extend from a "Web::Processor" base role/class ?

use Moose::Role;
###use namespace::autoclean;

with('Logger');

# system id
requires 'id';

# maximum number of keyphrases considered per object
has 'limit' => ( is => 'ro' , isa => 'Num' , default => 10 );

# TODO : can we add signature requirements ?
requires 'extract';

# CURRENT : the real problem is segmentation for multi-word terms
# CURRENT : full graph replacement or single path ?

# truncate list of extracted keyphrases and perform type lookups
after "extract" => sub {

};

###__PACKAGE__->meta->make_immutable;

1;
