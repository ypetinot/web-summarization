package Category::Data;

use strict;
use warnings;

# Raw data as directly obtained from the category entries
# Model-like representation needs to go into the GraphModel class

use Category::Folds;
use Category::UrlData;
use CycleChecker;
use Chunk;
use GraphSummarizer;

use Clone qw/clone/;
use File::RsyncP;
use File::Slurp;
use JSON;
use Memoize;
use Encode;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;
use namespace::autoclean;

#with CycleChecker;
with Storage('format' => 'JSON', 'io' => 'File');

# TODO : to be removed
=pod
# serialization file extension
our $CATEGORY_DATA_SERIALIZATION_EXTENSION = "opt.graph.summary.chunks";
=cut

# (parent) repository
#has 'repository' => ( is => 'ro' , isa => 'DMOZ::CategoryRepository' , required => 1 );
has 'repository' => ( is => 'rw' , required => 1 );

# fields
has 'summaries' => (is => 'ro', isa => 'ArrayRef');

# category data base (should be relative to the serialization file)
# CURRENT / TODO : prevent external access to this field ?
# Note: can be remote => if so must currently mirrored locally
has 'category_data_base' => ( is => 'bare' , isa => 'Str' , required => 0 , traits => [ 'DoNotSerialize' ] , trigger => \&_update_category_data_base_local );
has 'category_data_base_local' => ( is => 'rw' , isa => 'Str' , init_arg => undef );
sub _update_category_data_base_local {
    my $this = shift;
    my $new_value = shift;
    my $old_value = shift;
    
    my $category_data_base_local = undef;

    # check whether base is local
    # TODO: is this test accurate enough ?
    if ( $new_value =~ m/\:\:(.*)$/ ) {
	# this is a remote base
	$category_data_base_local = $this->generate_local_mirror( $1 );
    }
    else {
	# this
	$category_data_base_local = $new_value;
    }

    # set category_data_base_local
    $this->category_data_base_local( $category_data_base_local );

}

has '_local_mirror' => ( is => 'rw' , isa => 'File::Temp::Dir' , init_arg => undef , lazy => 1 , builder => '_local_mirror_builder' );
sub _local_mirror_builder {
    my $this = shift;
    return File::Temp->newdir;
}

has 'repository_host' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_repository_host_builder' );
sub _repository_host_builder {
    my $this = shift;
    return $ENV{DMOZ_REPOSITORY_HOST};
}

has 'repository_port' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_repository_port_builder' );
sub _repository_port_builder {
    my $this = shift;
    return $ENV{DMOZ_REPOSITORY_PORT};
}

has 'repository_module' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_repository_module_builder' );
# TODO : read from configuration
sub _repository_module_builder {
    my $this = shift;
    return 'repository';
}

has 'repository_user' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_repository_user_builder' );
# TODO : read from configuration
sub _repository_user_builder {
    my $this = shift;
    return 'odp';
}

has 'repository_password' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_repository_password_builder' );
# TODO : read location from configuration ?
sub _repository_password_builder {
    my $this = shift;
    my $password = read_file( '/home/ypetinot/rsyncd.user' );
    chomp $password;
    return $password;
}

sub generate_local_mirror {

    my $this = shift;
    my $data_base = shift;

    # 1 - get local mirror base
    my $mirror_base = $this->_local_mirror;

    # 2 - create rsync client
    my $rs = File::RsyncP->new({
	logLevel   => 0,
	rsyncCmd   => "/bin/rsync",
	rsyncArgs  => []
			       });
    
    # 3 - rsync from remote database to local mirror
    $rs->serverConnect( $this->repository_host , $this->repository_port );
    $rs->serverService( $this->repository_module , $this->repository_user , $this->repository_password , 0 );
    # TODO : how to remove chown warning ?
    $rs->serverStart( 1 , "${data_base}*" );
    $rs->go( "$mirror_base/" );
    $rs->serverClose;
    
    # 4 - make sure the mirror is ready to be used
    # TODO ?

    my @data_base_components = split /\// , $data_base;
    my $data_filename = $data_base_components[ $#data_base_components ];
    return join( "/" , $mirror_base->dirname , $data_filename );

}

subtype 'HashRefOfStrs',
    as 'HashRef[Str]';

coerce 'HashRefOfStrs',
    from 'ArrayRef[Str]',
    via { my %hash; map { $hash{ $_ } = 1; } @{ $_ }; \%hash; };

# target urls ( optional - allows to load data for specific URLs )
has 'target_urls' => (is => 'ro', isa => 'HashRefOfStrs', required => 0 , coerce => 1 );

# url entries (raw)
has '_url_entries' => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_url_entries_builder');

# urls
has 'urls' => (is => 'ro', isa => 'ArrayRef', lazy => 1, required => 0, builder => '_urls_builder');

# url to index mapping
has 'url_2_index' => (is => 'ro', isa => 'HashRef', lazy => 1, required => 0, builder => '_url_index_builder');

# category url data
has 'url_data' => (is => 'ro', isa => 'HashRef[Category::UrlData]', lazy => 1, required => 0, builder => '_url_data_builder' , traits => [ 'DoNotSerialize' ]);

# data process cache
has '_data_process_cache' => (is => 'rw', isa => 'HashRef', default => sub { {} }, traits => [ 'DoNotSerialize' ]);

# mappings
has '_mappings' => (is => 'rw', isa => 'HashRef', default => sub { {} }, traits => [ 'DoNotSerialize' ]);

# mappings_surface
has '_mappings_surface' => (is => 'rw', isa => 'HashRef', default => sub { {} }, traits => [ 'DoNotSerialize' ]);

# folds
# TODO : go back to an ArrayRef[Fold] ?
has 'folds' => ( is => 'ro' , isa => 'Category::Folds' , init_arg => undef , lazy => 1 , builder => '_folds_builder' );
sub _folds_builder {
    my $this = shift;
    return new Category::Folds( category_data => $this );
}

# get category id
sub url_category {

    my $this = shift;
    my $url = shift;

    return $this->_url_entries()->[ $this->url_2_index()->{ $url } ]->[ 1 ];

}

# get gist count
sub get_gist_count {
    my $this = shift;
    return scalar( @{ $this->summaries } );
}

# method to access chunks by their ids
sub get_chunk {

    my $this = shift;
    my $chunk_id = shift;
    my $must_have = shift;

    # by default we abort when an unknown chunk is requested
    if ( ! defined( $must_have ) ) {
	$must_have = 1;
    }

    # TODO: add chunk indexing
    my $chunks = $this->chunks();
    foreach my $chunk (@$chunks) {

	if ( $chunk->id() == $chunk_id ) {
	    return $chunk;
	}

    }

    if ( $must_have ) {
	die "(" . ref($this) . ") Unable to find chunk for requested id: $chunk_id";
    }
    else {
	return undef;
    }

}

# get all gists (as represented by their ids) where a given chunk appears
sub get_appearances {

    my $this = shift;
    my $chunk_id = shift;

    my @appearances;

    my @summaries = @{ $this->summaries() };
    for (my $i=0; $i<scalar(@summaries); $i++) {

	my $summary = $summaries[$i];

	my @summary_chunks = @{ $summary };
	foreach my $summary_chunk_id (@summary_chunks) {
	    if ( $summary_chunk_id == $chunk_id ) {
		push @appearances, $i;
		last;
	    }
	}

    }

    return \@appearances;

}

# get summaries with filter
sub filtered_summaries {

    my $this = shift;
    my $filter = shift;

    my @summaries = map {

	my @all_elements = map { $this->get_chunk($_); } @{ $_ };
	my @filtered_elements;

	if ( defined($filter) ) {
	    @filtered_elements = grep { $filter->( $_ ); } @all_elements;
	}
	else {
	    @filtered_elements = @all_elements;
	}
				 
	\@filtered_elements;

     } @{ $this->summaries };

    return \@summaries;

}

# read in data from a stream (STDIN for now)
sub read_in_data {

    my $that = shift;
    my $input_file = shift;

    local $/ = undef;
    my $content = undef;
    if ( ! defined($input_file) ) {
	$content = <STDIN>;
    }
    else {
	open INPUT_FILE, $input_file or die "Unable to open category file $input_file: $!";
	$content = <INPUT_FILE>;
	close INPUT_FILE;
    }
    
    chomp $content;
    my $deserialized = $that->deserialize($content);

    return $deserialized;
    
}

# write out data to a stream (STDOUT for now)
sub write_out_data {

    my $that = shift;

    my $serialized = $that->serialize;
    print STDOUT "$serialized";
    
}

# pre-serialization preparation
sub pre_serialize {

    my $this = shift;

    # Nothing by default

}

# serialize data to a string
sub serialize {

    my $this = shift;

    $this->pre_serialize;
    return $this->freeze;

}

# deserialize data from a string
sub deserialize {

    my $that = shift;
    my $string = shift;
    
    my $deserialized = __PACKAGE__->thaw($string);

    return $deserialized;

}

# TODO : remove if not used
=pod
# restore
sub restore {

    my $that = shift;
    my $category_base = shift;

    my $serialization_file = $that->serialization_file( $category_base );

    my $obj = $that->load( $serialization_file );
    $obj->category_data_base( $category_base );

    return $obj;

}
=cut

# TODO : to be removed
=pod
# serialization file
sub serialization_file {

    my $that = shift;
    my $category_base = shift;

    return join(".", $category_base, $CATEGORY_DATA_SERIALIZATION_EXTENSION);

}
=cut

# get category data (i.e. this !)
# We add this method so that Category::Data and Category::Fold expose the same interface/have consistent behaviors
sub category_data {

    my $this = shift;

    return $this;

}

# get index for a URL
sub get_url_index {

    my $this = shift;
    my $url = shift;

    return $this->url_2_index->{ $url };

}

# load data for a specific URL
sub load_url_data {

    my $this = shift;
    my $url = shift;

    return $this->url_data->{ $url };

}

# build url entries
sub _url_entries_builder {

    my $this = shift;

    my ($urls,$temp) = $this->load_category_file;
    my $n_urls = scalar( @{ $urls } );
    
    my @url_entries;
    for (my $i=0; $i<$n_urls; $i++) {
	push @url_entries, [ $urls->[ $i ] , $temp->[ $i ] ];
    }
    
    return \@url_entries;

}

# build urls
sub _urls_builder {

    my $this = shift;

    # we need the url index for this
    my $index = $this->url_2_index;
    
    my @urls = sort { $index->{ $a } <=> $index->{ $b } } keys( %{ $index } );

    return \@urls;

}

# build url index field
sub _url_index_builder {

    my $this = shift;

    my $url_entries = $this->_url_entries;

    my %hash;
    for (my $i=0; $i<scalar(@{ $url_entries }); $i++) {
	$hash{ $url_entries->[ $i ]->[ 0 ] } = $i;
    }

    return \%hash;

}

# build url data field
sub _url_data_builder {

    my $this = shift;

    my %url_data_instances;

    my @urls = keys( %{ $this->url_2_index } );

    for (my $i=0; $i<scalar(@urls); $i++) {
	
	my $current_url = $urls[ $i ];

	if ( defined( $this->target_urls ) && ( ! $this->target_urls->{ $current_url } ) ) {
	    next;
	}

	# create UrlData instance
	my $url_data = new Category::UrlData( 
	    global_data => $this->repository->global_data,
	    category_data => $this,
	    url => $current_url,
	    fields => { } );
	
	# append the new UrlData instance to the list of instance
	$url_data_instances{ $current_url } = $url_data;
	
    }

    return \%url_data_instances;

}

# get category file name
sub category_file_name {

    my $this = shift;
    my @specs = @_;

    my @file_components = ( $this->category_data_base_local );
    if ( scalar( @specs ) ) {
	push @file_components, ( grep { length($_); } @specs );
    }

    return join(".", @file_components);

}

# load category file
sub load_category_file {

    my $this = shift;
    my $file_name = shift || '';
    my $is_json = shift || 0;

    # load content data
    my $field_file_path = $this->category_file_name( $file_name );
    my ( $urls , $data ) = $this->_load_contents( $field_file_path , 1 , $is_json);

    return ($urls,$data);

}

# load contents file (don't we have a library to handle this ?)
sub _load_contents {

    my $this = shift;
    my $filename = shift;
    my $has_urls = shift;
    my $is_json = shift;

    if ( ! defined($has_urls) ) {
	$has_urls = 1;
    }  

    if ( ! defined($is_json) ) {
	$is_json = 0;
    }

    my @urls; 
    my @contents;

# TODO : comment back in once the issue with parallel in distributed mode has been resolved
###    print STDERR "($this) Loading content from: $filename ...\n";

    open CONTENTS_FILE, $filename or die "Unable to open file $filename: $!";
    binmode(CONTENTS_FILE, ':encoding(UTF-8)');

    while ( <CONTENTS_FILE> ) {

	chomp;
	my $line = $_;

	my @fields = split /\t/, $line;

	if ( $has_urls ) {
	    my $url = shift @fields;
	    if ( ref($this) && defined( $this->target_urls ) && ( ! $this->target_urls->{ $url } ) ) {
		next;
	    }
	    push @urls, $url;
	}

	my $data = join("\t", @fields);
	if ( $is_json ) {
	    # make sure we have valid UTF-8 here ?
#	    if ( ! utf8::is_utf8( $data ) ) {
#		print STDERR "Problem: input JSON data is not properly UTF-8 encoded ...\n";
#	    }
	    eval {
		$data = decode_json( $data );
	    };
	    if ( $@ ) {
		print STDERR "An error occurred while decoding JSON content: $data\n";
		$data = undef;
	    }
	}

	push @contents, $data;

    }
    close CONTENTS_FILE;

    my @results;
    if ( $has_urls ) {
	push @results, \@urls;
    }
    push @results, \@contents;

    return @results;

}

# has data field
sub has_data_field {

    my $this = shift;
    my $field_name = shift;

    return ( -f $this->category_file_name( $field_name ) );

}

# load data field
sub load_data_field {

    my $this = shift;
    my $field_name = shift;
    my $process = shift || undef;
    my $load_mapping = shift || 0;

    # TODO: create a feature object so we don't duplicate the field key generation (c.f. UrlData) ?
    my $field_key = Category::UrlData->field_key( $field_name , $process );

    my ($urls,$data) = $this->load_category_file( $field_name );

    my $process_sub = ref( $process ) ? $process : $this->_get_process_sub( $process );

    for (my $i=0; $i<scalar(@{$urls}); $i++) {
	my $url = $urls->[ $i ];
	my $datum = $data->[ $i ];
	# TODO : is this ok ?
	my $processed_datum = ( $process_sub && $datum ) ? &{ $process_sub }( $datum ) : $datum;
	$this->url_data->{ $url }->fields->{ $field_key } = clone( $processed_datum );

    }

    if ( $load_mapping ) {
	# load mapping data
	my ( $field_mapping , $field_mapping_surface ) = $this->_load_mapping_file( $field_name );
	$this->_mappings->{ $field_name } = clone( $field_mapping );
	$this->_mappings_surface->{ $field_name } = clone( $field_mapping_surface );
    }

    #if ( $@ ) {
    #print STDERR "An error occurred while updating the category url data: $@\n";
    #}

    return $field_key;

}

# load mapping file
sub _load_mapping_file {

    my $this = shift;
    my $field_name = shift;

    my $mapping_file_name = $this->category_file_name( $field_name , 'mapping' );
    my %mapping;
    my %mapping_surface;

    if ( open MAPPING_FILE, $mapping_file_name ) {

	my $version = undef;

	while ( <MAPPING_FILE> ) {
	    
	    chomp;
	    
	    my @fields = split /\t/, $_;

	    my $current_version = scalar( @fields );

	    # TODO: remove old format mapping files so I can get rid of this
	    if ( ! defined( $version ) ) {
		$version = $current_version;
	    }
	    elsif ( $version != $current_version ) {
		print STDERR "Mapping file format mismatch: $current_version column(s) instead of $version ...\n";
	    }

	    my $key = shift @fields;

	    my $value = undef;
	    if ( $version >= 3 ) {
		$value = shift @fields;
	    }
	    else {
		$value = $key;
	    }
	    my $surface = shift @fields;

	    $mapping{ $key } = $value;	    
	    $mapping_surface{ $key } = clone( $surface );
	    
	}
	
	close MAPPING_FILE;

    }
    else {
	print STDERR "Unable to open file $mapping_file_name: $!";
    }

    return ( \%mapping , \%mapping_surface );

}

# generate process sub
sub _get_process_sub {

    my $this = shift;
    my $process = shift;

    if ( $process ) {

	if ( ! defined( $this->_data_process_cache()->{ "$process" } ) ) {

	    my $process_sub = sub {

		no strict; 
		my $data = shift;

		my $processed_data = $data;

		my @process_specs = split /\//, $process;
		foreach my $process_spec (@process_specs) {
		    
		    my @process_sub_specs = split /::/, $process_spec;
		    my $process_command = shift @process_sub_specs;
		    my @process_command_args = @process_sub_specs;

		    # TODO : ultimatily only the ref option should be acceptable (c.f. UrlData/Modality)
		    if ( ! ref( $process_command ) ) {
			$processed_data = &{ $process_command }( $processed_data , @process_command_args );
		    }
		    else {
			$processed_data = $process_command->( $processed_data , @process_command_args );
		    }

		};

		return $processed_data;

	    };

	    $this->_data_process_cache->{ $process } = $process_sub;
	    
	}

	return $this->_data_process_cache()->{ $process };

    }
    
    return undef;

}

# make sure that url entries are compatible
sub _compatible_data {

    my $urls = shift;
    my $urls2 = shift;

    if ( scalar( @{$urls} ) != scalar( @{$urls2} ) ) {
	return 0;
    }
    else {
	for (my $i=0; $i<scalar(@{$urls}); $i++) {
	    if ( $urls->[ $i ] ne $urls2->[ $i ] ) {
		return 0;
	    }
	}
    }

    return 1;

}

# TODO: move this to an external library ?
sub count_filter {

    my $data = shift;
    my $count_threshold = shift;

    my %output_data;
    map{ $output_data{ $_ } = $data->{ $_ }; } grep { $data->{ $_ } > $count_threshold } keys( %{ $data } );

    return \%output_data;

}

sub release {

    my $this = shift;

    # disconnect from repository
    $this->repository( undef );

    foreach my $url (keys( %{ $this->url_data } )) {
	delete $this->url_data->{ $url };
    }

}

sub get_fold {
    my $this = shift;
    my $fold_id = shift;
    return $this->folds->get_fold( $fold_id );
}

__PACKAGE__->meta->make_immutable;

1;
