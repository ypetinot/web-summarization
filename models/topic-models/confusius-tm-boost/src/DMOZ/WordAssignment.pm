package DMOZ::WordOrigin;

# this package handles the logic of determining the origin of words
# over the DMOZ hierarchy

# constructor
sub new {

    my $that = shift;
    my $hierarchy = shift;

    my $class = ref($that) || $that;

    my $ref = {};
    $ref->{_hierarchy} = $hierarchy;
    
    bless $ref, $class;

    return $ref;

}

sub get_hierarchy_word_assignments {

    my $target_category = shift;

    return 

}

# returns the category that is the most likely source of the specify word
# this is wrt the specified target (leaf) category
sub origin {

    my $this = shift;
    my $category_ancestors = shift;
    my $word = shift;

    # starting a the current (target) category, climb the tree looking for the first
    # node to which word is assigned. Returns undef if no such node is found
    for (my $i=0; $i<scalar(@$category_ancestors); $i++) {

	my $current = $category_ancestors->[$i];

	# check the current category
	if ( $current->

    }

}
