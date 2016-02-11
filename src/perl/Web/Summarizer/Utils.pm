package Web::Summarizer::Utils;

use strict;
use warnings;

sub load_class {
    
    my $class_name = shift;
    
    eval( "use $class_name;" );
    if ( $@ ) {
	die "An error occurred while loading custom class $class_name: $@";
    }
    
    return $class_name;
    
}

1;
