package GistGraph::Node::Extractor::Function;

use strict;
use warnings;

use Moose;
use MooseX::Storage;

use GistGraph::Node::Extractor;
use NPModel::Extractor;
use Similarity;

extends 'GistGraph::Node::Extractor';

with Storage('format' => 'JSON', 'io' => 'File');

# fields
has 'model_path' => (is => 'ro', isa => 'Str', required => 0);
has 'function' => (is => 'rw', isa => 'NPModel::Extractor', init_arg => undef, required => 0);

# constructor
sub BUILD {

    my $this = shift;
    my $args = shift;

    # run extractor function training
    # for now we train a linear-chain CRF based on the data/values provided to the constructor
    
    # Why oh why isn't Moose constructing the parent class first ?
    my $extractor_function = $this->_generate_extractor_function();
    $this->function( $extractor_function );

}

# given one or more (content, (explicit) NP) pairs, learn a function that in all cases ranks that NP first
 
# 1 - contextual features for every individual words
# 2 - learn max-ent model over these features

# 4/5 binary features that can be used by a MaxEnt model"
# features that appear at least ... twice ?
# - unigram, bigram --> identity of previous one, two tokens
# - token appears in title (i.e. within <title> markers)
# - token appears in body (i.e. within <body> markers)
# - token appears in link (i.e. within <a> markers)

# TODO: unique chunks (regular NPs only ?) that appear in dictionaries should not be modeled as an extractor function

sub _generate_extractor_function {
    
    my $this = shift;

    my @content_data = map { $_->fields()->{'content::prepared'}; } @{ $this->url_data() };

    my $np_extractor = new NPModel::Extractor(
	base_directory => join("/", $this->model_path(), $this->id()),
	contents => \@content_data,
	target => $this->targets(),
	bin_root => $FindBin::Bin
	);
    $np_extractor->initialize();
    $np_extractor->train();
    $np_extractor->finalize();

    return $np_extractor;

}

# extraction method
sub extract {

    my $this = shift;

    # TODO: create class to conveniently have all the data for one URL encapsulated in a single object ?  
    my $raw_data = shift;
    my $target_id = shift;

    return undef;

}

no Moose;

1;
