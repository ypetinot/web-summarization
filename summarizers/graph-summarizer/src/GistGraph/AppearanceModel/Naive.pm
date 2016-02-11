package GistGraph::AppearanceModel::Naive;

# Naive (no correlation assumption) Appearance Model

# run inference
sub run_inference {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;

    # run multi-label classification
    my $node_appearances = $this->classifier()->classify( $url_data );

    # finally update appearance field
    map { $this->appearance()->{ $_ } = $node_appearances->{$_}; } keys( %{ $node_appearances } );

}

no Moose;

1;
