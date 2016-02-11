package CycleChecker;

use Moose::Role;

# make this be the parent class for all objects you want to check;
# or alternatively, stuff this into the UNIVERSAL class's destructor
use strict;
use warnings;
use Devel::Cycle;   # exports find_cycle() by default

sub DESTROY
{
    my $this = shift;

    # callback will be called for every cycle found
    find_cycle($this, sub {
	my $path = shift;
            foreach (@$path)
            {
                my ($type,$index,$ref,$value) = @$_;
                print STDERR "Circular reference found while destroying object of type " .
                    ref($this) . "! reftype: $type\n";
                # print other diagnostics if needed; see docs for find_cycle()
            }
	       });

    # perhaps add code to weaken any circular references found,
    # so that destructor can Do The Right Thing
}

1;
