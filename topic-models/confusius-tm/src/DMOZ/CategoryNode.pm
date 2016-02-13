package DMOZ::CategoryNode;

use strict;
use warnings;

use Data::Dumper;

use DMOZ::Node;

use base qw(DMOZ::Node);

# constructor
sub new {

    my $that = shift;
    my $name = shift;

    my $class = ref($that) || $that;

    # object ref / build base class
    my $hash = $that->SUPER::new($name, 'category');

    # create an array to hold the ids of all
    # leaf nodes under this category
    my @children;
    $hash->{_children} = \@children;

    # create an array to hold the ids of all
    # leaf nodes under this category
    my @leaves;
    $hash->{_leaves} = \@leaves;

    bless $hash, $class;

    return $hash;

}

# get the number of entries in this category
sub numberUrlEntries {

    my $this = shift;
    
    return scalar(@{$this->{_leaves}});

}

# get a particular URL entry in this category
sub getEntry {

    my $this = shift;
    my $hierarchy = shift;
    my $index = shift;

    if ( ($index < 0) || ($index > $#{$this->{_leaves}}) ) {
	return undef;
    }

    return $hierarchy->getEntry($this->{_leaves}->[$index]);

}

# get all URL entries in this category
sub getAllEntries {

    my $this = shift;
    my $hierarchy = shift;
    
    my @entries = map { $hierarchy->getEntry($_) } @{ $this->{_leaves} };

    return \@entries;

}

# override getChildren
sub getChildren {

    my $this = shift;
    my $filter_func = shift;

    my @children;

    # first get regular children
    push @children, map { $this->getHierarchy()->getNode($_) } @{ $this->{_children} };

    # second add url entries under this node
    push @children, map { $this->getHierarchy()->getNode($_) } @{ $this->{_leaves} };

    if ( defined($filter_func) ) {
	@children = grep { $filter_func->($_); } @children;
    }

    return \@children;

}

# override getDescendants
sub getDescendants {

    my $this = shift;
    my $filter_func = shift;
    
    my @descendants;
    
    my @children = $this->getChildren();
    foreach my $child (@children) {

	# run filter on this child
	if ( !defined($filter_func) || $filter_func->($child) ) {
	    push @descendants, $child;
	}

	# now recurse over child if it is a category
	if ( $child->type() eq 'category' ) {
	    push @descendants, @{ $child->getDescendants($filter_func) };
	}

    }

    return \@descendants;

}

# add a child to list of children
sub addChild {

    my $this = shift;
    my $node = shift;

    if ( ! $node ) {
	return;
    }

    # set child info
    if ( ref($node) eq 'DMOZ::EntryNode' ) {
	push @{$this->{_leaves}}, $node->id;
    }
    else {
	push @{$this->{_children}}, $node->id;
    }

    $this->sync();

}

# string representation of this entry
sub as_string {

    my $this = shift;
    
    return Dumper(

	{ 
	    name => $this->{_name},
	    n_entries => $this->numberUrlEntries(),
	    _processing => { 
		map {
		    $_ => $this->get($_)
		} $this->getHierarchy->listProcessingFields($this)
	    }
	}
	
	);

}

1;
