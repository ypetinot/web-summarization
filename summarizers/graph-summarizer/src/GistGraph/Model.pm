package GistGraph::Model;

# Base class for all models that use the Gist Graph as their base topology 

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# what model class elses have been loaded already (probably don't need to make this a class attribute)
our %loaded;

# load appearance model module
# TODO: is this the best place to do this ? could be implemented through a factory method in GistGraph::AppearanceModel
sub _load_model_module {

    my $this = shift;
    my $appearance_module_name = shift;

    if ( defined( $appearance_module_name ) && !defined( $loaded{ $appearance_module_name } ) ) {

	my $appearance_module_name_file = join(".", $appearance_module_name, "pm");
	$appearance_module_name_file =~ s/::/\//sg;
	
	require $appearance_module_name_file;
	
	$loaded{ $appearance_module_name } = 1;

    }

    return $appearance_module_name;

}

__PACKAGE__->meta->make_immutable;

1;
