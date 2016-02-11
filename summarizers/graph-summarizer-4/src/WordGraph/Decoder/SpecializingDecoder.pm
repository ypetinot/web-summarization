package WordGraph::Decoder::SpecializingDecoder;

# TODO : to be removed

# CURRENT : if applied to WordGraph how do we encode the replacement probability ?
# CURRENT : keyphrases included as part of Word-graph construction (i.e. just a different WordGraph::GraphConstructor class) 

with('WordGraph::Decoder');
requires('get_keyphrases');

# keyphrase extractor
has 'keyphrase_extractor' => ( is => 'ro' , isa => '' , init_arg => undef , lazy => 1 , builder => '_keyphrase_extractor_builder' );
sub _keyphrase_extractor_buil
