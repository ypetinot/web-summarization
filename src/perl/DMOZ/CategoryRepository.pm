package DMOZ::CategoryRepository;

use strict;
use warnings;

use Category::Data;

use Data::Serializer;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode qw(encode_utf8);
use File::Path;
use JSON;

my $DEFAULT_FIELD_VALUE = "__EMPTY_VALUE__";
my $URL_INDEX_FILTER_FILENAME = "_url_index_filter";
my $URL_INDEX_FILENAME = "_url_index";

my $MAX_CATEGORY_DEPTH = 4;

my $serializer = Data::Serializer->new(
    serializer => 'Storable',
#    serializer => 'JSON',
#    serializer => 'Data::Dumper',
#    compress   => 1,
    );

use Moose;
use namespace::autoclean;

# TODO : to be removed ?
=pod
# global data
# TODO : figure out how to combine DMOZ::GlobalData and DMOZ::CategoryRepository into a single class, or at least refactor them into something coherent ?
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , required => 1 );
=cut

# repository root
has 'repository_root' => ( is => 'ro' , isa => 'Str' , required => 1 );

# category cache
has '_category_cache' => ( is => 'ro' , isa => 'HashRef[Category::Data]' , init_arg => undef , default => sub { {} } );

# finalize
sub finalize {

    my $this = shift;
    
    # store url index
    $this->save_url_index();

}

# url index filter filename getter
sub _get_url_index_filter_filename {

    my $this = shift;
    
    return join("/", $this->repository_root, $URL_INDEX_FILTER_FILENAME);

}

# url index filename getter
sub _get_url_index_filename {

    my $this = shift;
    
    return join("/", $this->repository_root, $URL_INDEX_FILENAME);

}

=pod
# make sure that all fields are supported
# add them otherwise, provided field creation is unable
foreach my $field (@update_fields) {
    
    if ( ! $repository->has_field($field) ) {
	
	if ( $create_fields ) {
	    $repository->create_field($field);
	}
	else {
	    die "Field not supported: $field";
	}

    }

}
=cut

# get category unique id
sub category_unique_id {

    my $category = shift;

    my @category_path_elements = split /\// , $category;
    my $category_id = pop @category_path_elements;

    return $category_id;

}

# determines whether a category is available to client applications
sub category_available {

    my $this = shift;
    my $category = shift;

    if ( scalar( keys( %{ $this->{_url_index_filter} } ) ) ) {
	#TODO : can we make this check prettier ?
	my $category_id = $this->category_unique_id( $category );
	return defined( $this->{_url_index_filter}->{ $category_id } );
    }

    return 1;

}

# load url index
sub load_url_index {

    my $this = shift;

    my $url_index_filter = {};
    my $url_index = {};

    if ( open(URL_INDEX_FILTER_FILE, $this->_get_url_index_filter_filename()) ) {

	while( <URL_INDEX_FILTER_FILE> ) {

	    chomp;
	    my $category_id = $this->category_unique_id( $_ );
	    $url_index_filter->{ $category_id } = 1;

	}

    }

    if ( open(URL_INDEX_FILE, $this->_get_url_index_filename()) ) {
    
	local $/ = undef;
	my $file_content = <URL_INDEX_FILE>;
	$url_index = $serializer->deserialize($file_content);

	close FIELDS_FILE;

    }

    $this->{_url_index_filter} = $url_index_filter;
    $this->{_url_index} = $url_index;

}

# save url index
sub save_url_index {

    my $this = shift;

    my $url_index_file = $this->_get_url_index_filename();
    open(URL_INDEX_FILE, ">$url_index_file") or die "Unable to open url index file $url_index_file: $!";
    print URL_INDEX_FILE $serializer->serialize( $this->{_url_index} );
    close FIELDS_FILE;

}

# check wether a field has been registered
sub has_field {

    my $this = shift;
    my $field = shift;

    return defined($this->{_fields_indexes}->{$field});

}

# create a fields
sub create_field {

    my $this = shift;
    my $field = shift;

    # confirm that this field doesn't already exist
    if ( $this->has_field($field) ) {
	return;
    }

    push @{ $this->{_fields} }, $field;
    $this->{_fields_indexes}->{$field} = scalar( keys( %{ $this->{_fields_indexes} } ) );

}

sub get_local_category_filename {

    my $this = shift;
    my $category_name = shift;
    my $repository_depth = shift || $MAX_CATEGORY_DEPTH;

    # determine parent directory
    my @path_elements = split /\//, $category_name;
    if ( scalar(@path_elements) > $repository_depth ) {
	splice @path_elements, $repository_depth;
    }
    my $directory_name = join("/", @path_elements);

    # determine category file name
    my $category_filename = $category_name;
    $category_filename =~ s/\//\#\#/g;
    # Note : whatever encode_utf8 does it should have no effect on regular category names but will fix issues for the likes of http://www.sonoranseacondo.com (86e85d787f2e74b78ba93f5433568791 / 32f4d2e2305eaa70ed094efbd9ff13fa
    # http://barracuda.cs.columbia.edu:8080/solr_context/odp-index/select?q=url%3A%22http%3A%2F%2Fwww.sonoranseacondo.com%22&wt=json&indent=true
    $category_filename = md5_hex( encode_utf8( $category_filename) );
    
    # TODO: does this make sense ?
    my @results = ($directory_name, $category_filename);
    return wantarray ? @results : join( "/" , @results );
    
}

# read-in single data file
sub read_file {

    my $this = shift;
    my $filename = shift;

    my @data;

    open DATA_FILE, $filename or return undef;
    while(<DATA_FILE>) {
	chomp;
	my $line = $_;
	my @elements = split /\t/, $line;
	push @data, \@elements;
    }
    close DATA_FILE;

    if ( scalar(@data) ) {
	return \@data;
    }
    else {
	return undef;
    }

}

# write out single data file
sub write_file {

    my $this = shift;
    my $filename = shift;
    my $data = shift;

    if ( open DATA_FILE, ">$filename" ) {
	foreach my $data_element (@$data) {
	    print DATA_FILE join("\t",@$data_element) . "\n";
	}
	close DATA_FILE;
    }
    else {
	print STDERR "Unable to write to file $filename: $!\n";
    }

}

# create data for single data file
sub create_file {
    
    my $this = shift;
    my $reference_filename = shift;
    my $target_filename = shift;

    # for now no need to actually write out the data
    my $data = $this->read_file($reference_filename);
    if ( !defined($data) ) {
	return undef;
    }
    map { $_->[1] = ''; } @$data; 

    return $data;

}

# get category files
sub get_category_files {

    my $this = shift;
    my $url = shift;

    # find all categories in which this url appears
    my $category_files = $this->{_url_index}->{$url};
    if ( ! defined( $category_files ) ) {
	print STDERR "Unable to retrieve category information for url $url, skipping ...\n";
	return [];
    }

    # find the base file for our target category
    my @actual_category_files = map { join("/", $this->repository_root, $_); } grep { $this->category_available( $_ ) } @$category_files;

    return \@actual_category_files;

}

# update url data
sub update_url {

    my $this = shift;
    my $url = shift;
    my $field = shift;
    my $value = shift || $DEFAULT_FIELD_VALUE;

    # find all categories in which this url appears
    my @actual_category_files = @{ $this->get_category_files() };
    foreach my $category_file (@actual_category_files) {
	$this->update_url_category($url,$field,$value,$category_file);
    }

}

# get absolute filename for a given category
sub get_absolute_category_field_filename {

    my $this = shift;
    my $relative_filename = shift;
    
    return join("/", $this->repository_root, $relative_filename);

}

# get field filename for a given category
#sub get_category_field_filename {
sub get_category_filename {

    my $this = shift;
    my $category_name = shift;
    my $field_name = shift;

    my $category_field_filename = $this->get_local_category_filename($category_name);

    if ( defined( $field_name ) ) {
	# TODO : can we do better than this ?
	$category_field_filename = join( '.' , $category_field_filename , $field_name );
    }

    return $this->get_absolute_category_field_filename( $category_field_filename );

}

# update url data for a particular category
sub update_url_category {

    my $this = shift;
    my $url = shift;
    my $field = shift;
    my $value = shift;
    my $category_filename = shift;

    my $category_field_filename = join(".", $category_filename, $field);

    # 1 - read in data file for this field
    my $field_data = $this->read_file($category_field_filename);
    if ( !$field_data ) {
	# data file for this field does not exist
	# we create it here
	#print STDERR "creating $category_field_filename\n";
	$field_data = $this->create_file($category_filename,$category_field_filename);
    }
    else {
	#print STDERR "file already exists: $category_field_filename !\n";
    }
    
    if ( !$field_data ) {
	die "Unable to either access or create date file for field $field: $category_field_filename ...";
    }

    # update data
    foreach my $entry (@$field_data) {

	my $entry_url = $entry->[0];
	my $entry_value = $entry->[1];

	if ( $entry->[0] eq $url ) {
	    $entry->[1] = $value;
	}

    }

    # write out category data
    $this->write_file($category_field_filename,$field_data);

}

# TODO: there is some code redundancy with the other methods
sub get_category_base {

    my $this = shift;
    my $category_name = shift;

    my ($target_directory, $target_file) = $this->get_category_filename($category_name);
    my $local_target_file = join("/", $target_directory, $target_file);

    my $real_target_directory = join("/", $this->repository_root, $target_directory);
    my $real_target_file = join("/", $this->repository_root, $local_target_file);

    return $real_target_file;

}

# add url to repository
sub add_url {

    my $this = shift;
    my $category_name = shift;
    my $url = shift;
    my $overwrite = shift;

    # determine target file for this category
    my ($target_directory, $target_file) = $this->get_category_filename($category_name);
    my $local_target_file = join("/", $target_directory, $target_file);

    my $real_target_directory = join("/", $this->repository_root, $target_directory);
    my $real_target_file = join("/", $this->repository_root, $local_target_file);

    # create target directory
    mkpath($real_target_directory);

    # append URL to target file
    open TARGET_FILE, ">>$real_target_file" or die "Unable to open target file $real_target_file: $!";
    print TARGET_FILE join("\t", $url, $category_name) . "\n";
    close TARGET_FILE;

    # append information for this url to the url index
    if ( ! defined( $this->{_url_index}->{$url} ) || $overwrite ) {
	$this->{_url_index}->{$url} = [];
    }
    elsif ( ! $overwrite ) {
	print STDERR "Will not overwrite entry for url $url ...\n";
	next;
    }
    # TODO: can we get rid of this altogether ?
    # incorrect in case we have multiple categories for a given URL and we decide to overwrite for one of them ...
    push @{ $this->{_url_index}->{$url} }, $local_target_file;

}

# get data for a specific (URL,Category) pair
# TODO : as an alternative to memoization, make sure we maintain a cache of Category::Data objects at the CategoryRepository level.
sub get_url_data {

    my $this = shift;
    my $url = shift;
    my $url_category = shift;

    my $target_category_base = undef;

# TO BE REMOVED
##    # 1 - determine one of the categories to which this URL belongs
##    if ( ! $url_category ) {
##
##	# ( even if this URL belongs to multiple categories, the associated data will be the same )
##	my @actual_category_files = @{ $this->get_category_files( $url ) };
##	
##	if ( ! scalar(@actual_category_files) ) {
##	    return undef;
##	}
##	
##	$target_category_base = $actual_category_files[ 0 ];
##
##    }
##    else {
##

    # TODO : add more reliable test for absolute path
    if ( $url_category !~ m/^\// ) {
	# TODO : is this really ok ?
	$target_category_base = $this->get_category_filename( $url_category );
    }
    else {
	$target_category_base = $url_category;
    }

    my $category_data = $this->get_category_data( $target_category_base );

##
##    }
##

    my $requested_multiple = ref( $url );
    my $requested_urls = $requested_multiple ? $url : [ $url ];
    my @url_data = map { $category_data->load_url_data( $_ ) } @{ $requested_urls };

    return ( $requested_multiple ? \@url_data : $url_data[ 0 ] );

}

sub get_category_data_from_id {

    my $this = shift;
    my $category_id = shift;
    
    my $category_data_base = $this->get_category_filename( $category_id );

    return $this->get_category_data( $category_data_base );

}

# CURRENT: the category data specification should ideally be relative to the repository root (and should be the full category id ?)
sub get_category_data {

    my $this = shift;
    my $category_data_base = shift;

    if ( ! defined( $this->_category_cache->{ $category_data_base } ) ) {
	$this->_category_cache->{ $category_data_base } = new Category::Data( repository => $this , category_data_base => $category_data_base );
    }

    return $this->_category_cache->{ $category_data_base };

}

sub release_category {

    my $this = shift;
    my $category_data = shift;

    my $category_key = ref( $category_data ) ? $category_data->category_data_base : $category_data;

    if ( ref( $category_data ) ) {
	my $category_object = $this->_category_cache->{ $category_key };
	$category_object->release;
    }

    delete $this->_category_cache->{ $category_key };

}

__PACKAGE__->meta->make_immutable;

1;
