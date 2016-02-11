package WordGraph::ClassLoader;

# TODO : is this the best I can do to dynamically load classes ? / Can I rely on standard Perl class loaders ?

use Moose::Role;

sub load_class {

    my $this = shift;
    my $class_name = shift;
    
    eval( "use $class_name;" );
    if ( $@ ) {
	die "An error occurred while loading custom class $class_name: $@";
    }
    
    return $class_name;
    
}

1;
