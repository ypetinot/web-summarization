package DMOZ::Node;

# Nodes are threaded (maybe we want to create a DMOZ::ThreadedNode class that extends DMOZ::Node
# TODO: create ThreadedTree class and release it !

use strict;
use warnings;
#use threads ('yield',
#	     #'stack_size' => 64*4096,
#	     'exit' => 'threads_only',
#	     'stringify');

use Storable qw(store retrieve nstore store_fd nstore_fd freeze thaw dclone);

# constructor
sub new {

    my $that = shift;
    my $name = shift;
    my $type = shift;
    my $parent = shift;

    my $class = ref($that) || $that;

    # object ref
    my $hash = ();

    # this node's name
    $hash->{_name} = $name;

    # this node's type
    $hash->{_type} = $type;

    # this node's parent
    $hash->{_parent} = $parent;

    # has this node been updated
    $hash->{_dirty} = 0;

=pod
    # create job queue
    $hash->{_jobs} = new Thread::Queue;
    $hash->{_jobs_running} = 0;
    $hash->{_jobs_status}= 0;
=cut

    bless $hash, $class;

=pod
    # start job manager
    $hash->startJobManager();
=cut

    return $hash;

}

# returns this node's id
sub id {

    my $this = shift;
    my $value = shift;

    if ( defined($value) ) {
	$this->{_id} = $value;
    }

    return $this->{_id};

}

# test equality between two nodes
sub equals {

    my $this = shift;
    my $node = shift;

    if ( ! $node ) {
	return 0;
    }

    if ( $this->id() == $node->id() ) {
	return 1;
    }

    return 0;

}

# recurse
sub recurse {

    my $this = shift;
    my $mapper = shift;
    my $label = shift;
    my $path = shift || []; # nodes, and associated data on the current path
    my $data = shift || [];

    my $do_process = $this->processable($label);

    # execute pre function on this node
    if ( $do_process && $mapper ) {
	push @{$data}, $mapper->pre_process($this, $path, $data);
    }

    # update path
    push @{$path}, $this;

    # list all the sub categories
    my @subcategories = @{ $this->getChildren() };
    my @recursion_outputs;
    foreach my $subcategory (@subcategories) {
	
	no strict;

	if ( !$subcategory ) {
	    die "problem with category $this " . $this->name();
	}
	
	if ( scalar(@$path) != scalar(@$data) ) {
	    die "mismatch between path stack and data stack for " . $this->name();
	}

	push @recursion_outputs, $subcategory->recurse($mapper, $label, $path, $data);

    }

    # update path
    pop @{$path};

    my $result = undef;

    # execute post function on this node
    if ( $do_process && $mapper ) {
	$result = $mapper->post_process($this, $path, $data, \@recursion_outputs);
	pop @{$data};
    }

    return $result;

}

# get ancestors
sub ancestors {

    my $this = shift;

    my @ancestors;

    my $current_node = $this->get_parent;
    while ($current_node) {

	unshift @ancestors, $current_node;
	$current_node = $current_node->get_parent;

    }

    return \@ancestors;
    
}

# set parent node
sub setParent {

    my $this = shift;
    my $node = shift;

    if ( $node ) {
	$this->{_parent} = $node->id();
    }

}

# get parent node
sub getParent {

    my $this = shift;

    return $this->getHierarchy()->getNode($this->{_parent});

}

# set a particular field
sub set {

    my $this = shift;
    my $key = shift;
    my $value = shift;
    my $built_in = shift || 0;

    my $processing_field_store = undef;

    if ( $built_in ) {

	$this->{$key} = $value;
	$this->sync();

    }
    else {

	$processing_field_store = $this->getHierarchy->getProcessingField($key);
	if ( ! $processing_field_store ) {
	    return;
	}
	
	my $storable_ref = [ $value ];
	my $serialized_value = freeze($storable_ref);
	#my $serialized_value = $serializer->serialize($storable_ref);

	#$processing_field_store->{$this->id} = $serialized_value;
	$processing_field_store->put($this->id, $serialized_value);

    }

}

# get a particular field
sub get {

    my $this = shift;
    my $key = shift;

    if ( defined($this->{$key}) ) {
	return $this->{$key};
    }

    my $processing_field_store = $this->getHierarchy->getProcessingField($key);
    if ( ! $processing_field_store ) {
	return;
    }

    #my $serialized_value = $processing_field_store->{$this->id};
    #my $serialized_value = $processing_field_store->FETCH($this->name);
    my $serialized_value = $processing_field_store->get($this->id);

    if ( ! $serialized_value ) {
	return;
    }

    my $deserialized_value = thaw($serialized_value);
    #my $deserialized_value = $serializer->deserialize($serialized_value);

    if ( scalar(@$deserialized_value) != 1 ) {
    	return;
    }

    return $deserialized_value->[0];

    #return $deserialized_value;

}

# set a particular hash field
sub set_hash {

    my $this = shift;
    my $key = shift;
    my $sub_key = shift;
    my $value = shift;

    # get current hash
    my $current_value = $this->get($key);
    if ( ! $current_value ) {
	$current_value = ();
    }
    
    # update hash
    $current_value->{$sub_key} = $value;

    $this->set($key, $current_value);

}

# get a particular hash field
sub get_hash {

    my $this = shift;
    my $key = shift;
    my $sub_key = shift;

    return $this->get($key)->{$sub_key};

}

# get this node's name
sub name {

    my $this = shift;

    return $this->{_name};

}

# get this node's type
sub type {

    my $this = shift;
    
    return $this->{_type};

}

# return string representation of this category
sub as_string {

    my $this = shift;

    return $this->name();

}

# set/unset dirty flag
sub sync {
    my $this = shift;
    $this->getHierarchy()->setNode($this->id(), $this);
}

# set hierarchy
sub setHierarchy {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_hierarchy} = $hierarchy;

}

# get hierarchy
sub getHierarchy {

    my $this = shift;
   
    return $this->{_hierarchy};

}

# getChildren, default implementation (no children)
sub getChildren {

    my $this = shift;
    my $filter_funct = shift;

    return [];

}

# getDescendants, returning all the nodes found under this Node
sub getDescendants {

    my $this = shift;
    my $filter_funct = shift;
    
    return [];

}

# can this node be processed
sub processable {

    my $this = shift;
    my $label = shift;

    # by default any node can be processed
    return 1;

}

=pod
# submit a job for parallel processing
sub submitJob {

    my $this = shift;
    my $func_ref = shift;
    my $options = shift;

    #$this->{_jobs}->enqueue( [ $func_ref, $options ] );
    $this->{_jobs}->enqueue( );

}

# wait for all the jobs currently running
sub waitForAllJobs {

    my $this = shift;
    
    while( $this->{_jobs}->pending() || $this->{_jobs_running} ) {
	yield();
    }

    return;

}

# look for threaded tree library (maybe i can contribute one to CPAN ?)

# start the job manager (thread of its own)
sub startJobManager {

    my $this = shift;

    $this->{_jobs_status}= 1;

    threads->create( sub {

	while ( $this->{_job_status} || $this->{_jobs}->pending() ) {
	    
	    if ( $this->{_jobs}->pending() ) {
		
		# get the job
		my $entry = $this->{_jobs}->dequeue();
		my $job = $entry->[0];
		my $options = $entry->[1];
		
		# execute the job
		my $thr = threads->create( sub { $this->{_jobs_running}++; $job->(); $this->{_jobs_running}--; } );
		
	    }
	    
	    yield();
	    
	}
	
		     });

}

# stop the job manager
sub stopJobManager {

    my $this = shift;
    
    $this->{_jobs_status} = 0;

}
=cut

1;
