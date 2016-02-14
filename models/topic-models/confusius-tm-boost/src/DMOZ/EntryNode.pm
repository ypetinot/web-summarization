package DMOZ::EntryNode;

use strict;
use warnings;

use Data::Dumper;
use DMOZ::Node;

use base qw(DMOZ::Node);

# constructor
sub new {

    my $that = shift;
    my $url = shift;
    my $title = shift;
    my $description = shift;
    my $category = shift;

    my $class = ref($that) || $that;

    # object ref / build base class
    my $hash = $that->SUPER::new(join("/", ($category,$url)), 'entry');

    # set fields
    $hash->{url}  = $url;
    $hash->{title} = $title;
    $hash->{description} = $description;
    $hash->{category} = $category;

    bless $hash, $class;

    return $hash;

}

# title getter
sub title {
    my $this = shift;
    return $this->get('title');
}

# description getter
sub description {
    my $this = shift;
    return $this->get('description');
}

# string representation of this entry
sub as_string {

    my $this = shift;
    
    return Dumper(

	{ url => $this->{url},
	  title => $this->title(),
	  description => $this->description(),
	  index => $this->{_index},
	  _processing => { 
		map {
		    $_ => $this->get($_)
		} $this->getHierarchy->listProcessingFields($this)
	  },
	  parent => $this->{_parent}
	}

	);

}

# can this node be processed
sub processable {

    my $this = shift;
    my $label = shift;

    if ( ! defined($label) ) {
	return 1;
    }

    my $node_label = $this->get("label");

    if ( ! defined($node_label) ) {
	return 1;
    }

    return ($label eq $node_label);

}

1;
