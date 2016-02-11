package Category::Operator;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# default initialization method
sub initialize {

    # do nothing

}

# beginning of category event
sub start_category {

    # do nothing

}

# end of category event
sub end_category {

    # do nothing

}

# process
sub process {

    my $this = shift;
    my $instance = shift;

    # call underlying _process method
    $this->_process( $instance );

}

# default finalize method
sub finalize {

    my $this = shift;

    # Nothing

}

__PACKAGE__->meta->make_immutable;

1;
