package DMOZ::Hierarchy;

# Abstracts the DMOZ hierarchy (category nodes + url nodes)
# The hierarchy is entirely described through the categories hash table, where each entry maps from a
# category name to a Category object. Category object link to other category objects to effectively
# form the DMOZ Tree. The URL entries are stored in a separate serialized array (for memory efficiency)
# and are referenced in the Tree based on their index in this array. This approach makes is possible to
# load the complete DMOZ hierarchy in memory, while allowing quick (1 reference) access to individual
# URL entries.

# how do we inform the hierarchy that an Entry node has been modified ?

use strict;
use warnings;

use BerkeleyDB;
#use CDB_File;
use Data::Dumper;
use DB_File;
use File::Path;
use Data::Serializer;
use Storable qw(store retrieve nstore store_fd nstore_fd freeze thaw dclone);
use TokyoCabinet;

my $serializer = Data::Serializer->new(
    serializer => 'Storable',
#    serializer => 'JSON',
#    serializer => 'Data::Dumper',
#    compress   => 1,
    );

use DMOZ::CategoryNode;
use DMOZ::EntryNode;
use Vocabulary;

my $basename = "dmoz_hierarchy";
my $category_hash_ext = "dch";
my $entry_array_ext = "dea";
my $processing_field_ext = "dpf";
my $global_field_ext = "dgf";

# constructor
sub new {

    my $that = shift;
    my $path = shift;
    my $vocabulary = shift;
    
    my $class = ref($that)||$that;

    # the object itself
    my $hash = ();

    # store path info
    $hash->{_path} = $path;

    my %store_files = (
	'_dmoz_store_file' => join("/", $path, join(".", $basename, $entry_array_ext)),
	'_dmoz_name_2_id' => join("/", $path, join(".", $basename, $category_hash_ext))
    );

    # create path if it does not exist
    mkpath($path);
    if ( ! -d $path ) {
	return;
    }

    # store dirty bit
    $hash->{_dirty} = 0;
    $hash->{_dirty_list} = [];

    foreach my $array (keys %store_files) {

	my %new_array;

	my $tobj = tie %new_array, 'TokyoCabinet::HDB', $store_files{$array}, TokyoCabinet::HDB::OCREAT|TokyoCabinet::HDB::OWRITER|TokyoCabinet::HDB::ONOLCK, 5000000, undef, undef, TokyoCabinet::HDB::TLARGE|TokyoCabinet::HDB::TBZIP, 10000000;    
#	my $tobj = tie %new_array, 'TokyoCabinet::BDB', $store_files{$array}, TokyoCabinet::BDB::OCREAT|TokyoCabinet::BDB::OWRITER, 128, 256, 32749, 256, 10, TokyoCabinet::BDB::TLARGE;    
#	$hash->{$array} = \%new_array;

	if ( ! $tobj ) {
	    die "unable to load/create $array mapping ...";
	}

	$hash->{$array} = $tobj;

    }

    # processing fields (a collection of arrays)
    $hash->{_processing_fields} = ();

    # bless this object
    bless $hash, $class;

    # list available processing fields
    opendir(my $dh, $path) || die "could not open directory $path: $!";
    map { $hash->loadProcessingField($_); } map { my $name = $_; $name =~ s/.*?$basename\.(.*?)\.$processing_field_ext$/$1/; $name; } grep { /\.$processing_field_ext$/ && -f "$path/$_" } readdir($dh);
    closedir $dh;

    # store vocabulary info if provided
    if ( $vocabulary ) {

	$hash->{_vocabulary_file} = $vocabulary;

	# instantiate vocabulary
	$hash->setProperty('vocabulary', Vocabulary->load($vocabulary));

    }

    return $hash;

}

# load a new processing field, creates it if necessary
sub loadProcessingField {

    my $this = shift;
    my $field_name = shift;

    my $processing_field_store_file = join("/", $this->{_path}, join(".", $basename, $field_name, $processing_field_ext));

    my %processing_field;
    
    my $tobj = tie %processing_field, 'TokyoCabinet::HDB', $processing_field_store_file, TokyoCabinet::HDB::OCREAT|TokyoCabinet::HDB::OWRITER|TokyoCabinet::HDB::ONOLCK, 5000000, undef, undef, TokyoCabinet::HDB::TLARGE|TokyoCabinet::HDB::TBZIP, 10000000;    

    if ( ! $tobj ) {
	die "unable to load/create processing field store file: $processing_field_store_file : $BerkeleyDB::Error ...";
    }

    # store a reference to this hash
#    $this->{_processing_fields}->{$field_name} = \%processing_field;
    $this->{_processing_fields}->{$field_name} = $tobj;

}

# unload a processing field
sub unloadProcessingField {

    my $this = shift;
    my $field_name = shift;

    if ( ! $this->{_processing_fields}->{$field_name} ) {
	return;
    }

#    untie %{ $this->{_processing_fields}->{$field_name} };
    $this->{_processing_fields}->{$field_name}->close();

}

# return reference to the requested processing field (for the entire hierarchy)
sub getProcessingField {

    my $this = shift;
    my $field_name = shift;
    my $built_in = shift;

    if ( ! $this->{_processing_fields}->{$field_name} ) {
	$this->loadProcessingField($field_name, $built_in);
    }

    return $this->{_processing_fields}->{$field_name};

}

# return list of all available processing fields
sub listProcessingFields {

    my $this = shift;
    my $target_node = shift || undef;

    my @processing_field_names = keys(%{ $this->{_processing_fields} });

    if ( $target_node ) {

	@processing_field_names = grep { defined($this->{_processing_fields}->{$_}->{$target_node->name}) } @processing_field_names;

    }

    return @processing_field_names;

}

# retrieve a node based on its full name
sub getNodeFromName {

    my $this = shift;
    my $name = shift;

    my $node = undef;

#    my $node_id = $this->{_dmoz_name_2_id}->{$name};
    my $node_id = $this->{_dmoz_name_2_id}->get($name);
    if ( defined($node_id) ) {
	$node = $this->getNode($node_id);
    }

    return $node;

}

# create CategoryNode under this node
sub createCategoryNode {

    my $this = shift;
    my $category_name = shift;

    my @subcategories = split /\//, $category_name;

    my $current_parent_node = undef;
    my $current_subcategory_node = undef;
    for (my $i=0; $i<scalar(@subcategories); $i++) {

	my $current_subcategory = join("/", @subcategories[0..$i]);

	# check if subcategory node exists
	$current_subcategory_node = $this->getNodeFromName($current_subcategory);
	if ( ! $current_subcategory_node ) {
	    
            # create category node
	    $current_subcategory_node = new DMOZ::CategoryNode($current_subcategory);

            # add category node to the set of categories (direct pointer)
	    $this->addNode($current_subcategory_node);
	    if ( $current_parent_node ) {
		$current_subcategory_node->setParent($current_parent_node);
		$current_parent_node->addChild($current_subcategory_node);
	    }

	}

	# prepare for the next iteration
	$current_parent_node = $current_subcategory_node;

    }

    return $current_subcategory_node;

}

# create URL Entry and place it in pool
sub createEntry {

    my $this = shift;
    my $url = shift;
    my $title = shift;
    my $description = shift;
    my $category = shift;

    # get category node
    my $category_node = undef;

    if ( ! $category ) {
	return undef;
    }
    elsif ( ref($category) ) {
	$category_node = $category;
    }
    else {
	$category_node = $this->getNodeFromName($category);
	# create category node if needed
	if ( !$category_node ) {
	    $category_node = $this->createCategoryNode($category);
	}
    }
    
    # skip if unable to create category node
    if ( ! $category_node ) {
	# print STDERR "[$0] unable to create category node for $category\n";
	return undef;
    }

    # create entry node
    my $entry_node = new DMOZ::EntryNode($url, $title, $description, $category);

    $this->addNode($entry_node);
    $entry_node->setParent($category_node);
    $category_node->addChild($entry_node);

    return $entry_node;

}

# registers new node (either CategoryNode or EntryNode)
sub addNode {

    my $this = shift;
    my $node = shift;
    my $parent_node = shift;

    # register node
    $this->setNode(-1, $node, 1);

    # register node name
    # TODO: allow for multiple nodes for a given name ?
#    $this->{_dmoz_name_2_id}->{$node->name()} = $node->id();
    $this->{_dmoz_name_2_id}->put($node->name(),$node->id());

    # this node is part of the current hierarchy
    $node->setHierarchy($this);

    return $node;

}


sub getNumberOfNodes {
    my $this = shift;
    return $this->{_dmoz_store_file}->rnum();
}

# access a particular Node
sub getNode {

    my $this = shift;
    my $index = shift;

    if ( $index < 0 || $index > $this->getNumberOfNodes() - 1 ) {
	return undef;
    }

#    my $packed_entry = $this->{_dmoz_store_file}->{$index};
    my $packed_entry = $this->{_dmoz_store_file}->get($index);

    my $unpacked_entry = $this->_unpack_entry($packed_entry);

    $unpacked_entry->setHierarchy($this);

    return $unpacked_entry;

}

# set a particular Node entry
sub setNode {

    my $this = shift;
    my $index = shift;
    my $node = shift;
    my $is_new_node = shift || 0;

    if ( ! defined($index) ) {
	die "big problem: $index " . $node->as_string . "\n";
    }

    if ( $is_new_node ) {
	# set node id
	$index = $this->getNumberOfNodes();
	$node->id($index);

    }
    else {
	if ( $index < 0 || $index > $this->getNumberOfNodes() ) {
	    return undef;
	}
    }

    # unset hierarchy information
    $node->setHierarchy(undef);

    # store node
#    $this->{_dmoz_store_file}->{$index} = $this->_pack_entry($node);
    $this->{_dmoz_store_file}->put($index, $this->_pack_entry($node));
    # set hierarchy information
    $node->setHierarchy($this);

    return $node;

}

# finalize model creation
sub finalize {

    my $this = shift;

    print STDERR "[$0] serializing hierarchy: " . $this->getNumberOfNodes() . " nodes ...\n";

    # unload all the processing fields
    foreach my $processing_field (keys(%{ $this->{_processing_fields}})) {
	$this->unloadProcessingField($processing_field);
    }

    # untie _leaves
#    untie %{ $this->{_dmoz_store_file} };
    $this->{_dmoz_store_file}->close();
    $this->{_dmoz_name_2_id}->close();

    return 1;

}

# map the specified function on all the URL entries
# the function returns a pair consisting of the mapped entry, and a boolean
# flag determining whether the entry needs to be updated
sub map_on_entries {

    my $this = shift;
    my $mapper = shift;
    my $label = shift;
    
    # 1 - initialize mapper
    $mapper->begin($this);

    my $n_mapped = 0;
    my $n_updated = 0;

    my $init_success = $this->{_dmoz_store_file}->iterinit();
    while ( defined( my $i = $this->{_dmoz_store_file}->iternext() ) ) {

	my $current_node = $this->getNode($i);

	if ( ref($current_node) !~ m/Entry/ ) {
	    next;
	}

	$n_mapped++;

	if ( !$current_node->processable($label) ) {
	    next;
	}

	$mapper->process($current_node);

    }

    # 2 - finalize mapper
    $mapper->end($this);

    return ($n_mapped, $n_updated);

}

# tree traversal
sub recurse {

    my $this = shift;
    my $mapper = shift;
    my $label = shift;

    my $start_node = $this->getNodeFromName("Top");

    if ( !$start_node ) {
	return;
    }

    # begin
    $mapper->begin($this);

    # recurse
    my $result = $start_node->recurse($mapper, $label, [], []);

    # end
    $mapper->end($this);

}

# pack entry data
sub _pack_entry {

    my $this = shift;
    my $unpacked_entry = shift;

    #my $packed_entry = freeze($unpacked_entry);
    my $packed_entry = $serializer->serialize($unpacked_entry);

    return $packed_entry;

}

# unpack entry data
sub _unpack_entry {

    my $this = shift;
    my $packed_entry = shift;

    #my $unpacked_entry = thaw($packed_entry);
    my $unpacked_entry = $serializer->deserialize($packed_entry);

    return $unpacked_entry;

}

# set hierarchy-wide property
sub setProperty {

    my $this = shift;
    my $key = shift;
    my $value = shift;

    my $serialized_value = $serializer->serialize($value);

    my $property_file_name = $this->_property_file_name($key);

    open PROPERTY_FILE, ">$property_file_name" or die "Unable to open propery file $property_file_name: $!";
    print PROPERTY_FILE $serialized_value;
    close PROPERTY_FILE;

}

# get hierarchy-wide property
sub getProperty {

    my $this = shift;
    my $key = shift;

    my $property_file_name = $this->_property_file_name($key);

    local $/ = undef;

    open PROPERTY_FILE, "$property_file_name" or die "Unable to open property file $property_file_name: $!";
    my $serialized_value = <PROPERTY_FILE>;
    close PROPERTY_FILE;

    my $value = $serializer->deserialize($serialized_value);

    return $value;

}

# get directory location for externally managed properties
sub getPropertyDirectory {

    my $this = shift;
    
    # get requested local path
    my @local_path = @_;

    # create target directory if required
    my $property_directory = $this->_property_file_name( join("-", @local_path) );
    mkpath $property_directory;

    return $property_directory;

}

# build property file name
sub _property_file_name {

    my $this = shift;
    my $key = shift;

    return join("/", $this->{_path}, join(".", ($basename, $key, $global_field_ext)));

}

1;
