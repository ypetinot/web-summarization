package DMOZ::Mapper::SimpleRecurser;

use DMOZ::Mapper;
use base qw(DMOZ::Mapper);

# pre-process
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;

    for (my $i=1; $i<scalar(@$path); $i++) {
	print STDERR "\t";
    }

    print STDERR "[simple recurser] entering " . $node->name() . " [" . join("|", $node->type(), $node->get('label')) . "]\n";

    # nothing

}


# post-process
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;

    for (my $i=1; $i<scalar(@$path); $i++) {
	print STDERR "\t";
    }

    print STDERR "[simple recurser] leaving " . $node->name() . "\n";

    # nothing

}

1;
