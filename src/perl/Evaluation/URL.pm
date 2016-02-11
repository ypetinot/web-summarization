package Evaluation::URL;

# all the data for a given URL

use Data::Dumper;
use URI;
use URI::Escape;
use File::Path;
use overload ('""' => 'url');

# DataManagers used to collect data for each URL
# in the future this could become configurable
my @data_managers;

BEGIN {
    
    @data_managers = (
		      "DataManagers::ContentDownloader", # level 1
		      "DataManagers::ContextDownloader", # level 2
		      "DataManagers::ContextCrawler",    # level 3
		      "DataManagers::ContextExtractor",  # level 4
		      );
    
# load data managers
    foreach my $data_manager (@data_managers) {  
	eval "require $data_manager";
	if ( $@ ) {
	    die $@;
	}
    }
}

# url escaping/encoding
sub url2uid {
    
    my $that = shift;
    my $url  = shift;

    return uri_escape($url);
    
}

# url unescaping
sub uid2url {

    my $that = shift;
    my $uid  = shift;

    return uri_unescape($uid);

}

# lock method
sub _lock {

    # noop for now
    return;

    my $this = shift;

    # lock directory
    flock(*{$this->{_URL_LOCK}},LOCK_EX);
    # and, in case someone appended
    # while we were waiting...
    seek(*{$this->{_URL_LOCK}}, 0, 2);

}

# unlock method
sub _unlock {

    # noop for now
    return;

    my $this = shift;

    # unlock directory
    flock(*{$this->{_URL_LOCK}},LOCK_UN);

}

# constructor
sub new {

    my $this = shift;
    my $package = ref($this) || $this;
    my $environment = shift;
    my $hash = shift || {};
    
    # set environment field
    $hash->{_ENVIRONMENT_OBJECT} = $environment;
        
    # bless
    bless $hash, $package;

    # create physical directory for this URL
    $hash->_init_data_directory();

    return $hash;

}

# destructor
sub DESTROY {

    my $this = shift;

    foreach my $key (keys(%{this})) {
	delete $this->{$key};
    }

}

# get absolute data directory for this URL
sub get_data_directory {
    my $this = shift;
    return $this->{_ENVIRONMENT_OBJECT}->get_root() . "/" . $this->{_data_directory};
}

# factory
sub instantiate {

    my $that = shift;
    my $url  = shift;
    my $environment = shift;
    my $doLoad = shift || 0;

    # hash
    my $hash = undef;
    if ( ! $doLoad ) {
	$hash = { url => $url };
    }
    else {
	# todo

	# map url 2 uid
	my $url = url2uid($url);

	# $hash = load ...
    }

    return $that->new($environment, $hash);

}


# ...
sub load {

    my $that = shift;
    my $file  = shift;
    my $environment = shift;

    local $/ = undef;
    open URL_DATA, $file or die "unable to open file $file: $!";
    my $data = <URL_DATA>;
    close URL_DATA;

    my $hash = eval($data);
    $hash->{_data_file} = $file;

    return $that->new($environment, $hash);

}

# serialize
sub serialize {

    my $this = shift;
    
    $this->_lock();

    # create copy of what needs to be serialized
    my $to_serialize = {};
    foreach my $key (keys(%{$this})) {

	if ( $key =~ m/^_/ ) {
	    next;
	}

	$to_serialize->{$key} = $this->{$key};

    }

    # open destination file
    my $destination_file = $this->{_data_file};
    open SERIALIZE, ">$destination_file" or die "unable to open file $destination_file: $!";
    print SERIALIZE Dumper( $to_serialize );
    close SERIALIZE;

    $this->_unlock();

}

# get URL string
sub url {

    my $this = shift;

    $this->_lock();

    my $result = $this->{url};

    $this->_unlock();

    return $result;

}

# get directory for this URL
sub _init_data_directory {

    my $this = shift;

    $this->_lock();

    # encode url
    my $encoded_url = $this->url2uid($this->{url});

    # extract host data
    # my $host = $this->url();
    # $host =~ s#^(?:https?|ftp)://([^\/:]+)(?:\:\d+)?/?.*$#$1#;
    # my @host_parts = split(/ */,join('',(split(/\./,$host))));
    # my $host_dirs = join('/',@host_parts);

    my $environment_root = $this->{_ENVIRONMENT_OBJECT}->get_root();
    # $this->{data_directory} = "$host_dirs/$encoded_url/";
    $this->{_data_directory} = $encoded_url;
    my $url_directory = $this->get_data_directory();
    mkpath($url_directory);

    $this->_unlock();

    return $url_directory;

}

# collect data for this URL
sub refresh_info {

    my $this = shift;
    my $up_to_level = shift || scalar(@data_managers);

    $this->_lock();

    # get current level
    my $current_level = $this->{level} || 1;

    for (my $level=1; $level<=$up_to_level && $level<=scalar(@data_managers); $level++) {
	
	# get data manager for the current level
	my $data_manager = $data_managers[$level-1];

	# run data manager
	my $success = $data_manager->run($this);

	# update level info
	if ( $level > $current_level ) {
	    $this->{level} = $level;
	}

    }

    # write out refreshed info
    $this->serialize();

    $this->_unlock();

}

# get list of files for a given URL and a given pattern
sub get_files {

    my $this = shift;
    my $file_pattern = shift;

    $this->_lock();

    # get url location in the environment
    my $url_location = $this->get_data_directory();

    # get all files matching the summary file pattern
    opendir(DIR, $url_location) || die "can't opendir $url_location: $!";
    @file_names = map { $url_location . "/" . $_ } grep { /$file_pattern/ && -f "$url_location/$_" } readdir(DIR);
    closedir DIR;

    $this->_unlock();

    return \@file_names;

}

# get list of all summary files current present
sub get_summary_files {

    my $this = shift;
    my $summarizer = shift;

    my $summarizer_file_pattern = qr/\.$summarizer(\-\d+)?$/;

    $this->_lock();

    # get all the files for this URL and this summarizer
    # TODO: summary files must have the summary (or description) extension
    my $summary_file_names = $this->get_files($summarizer_file_pattern);

    $this->_unlock();

    return $summary_file_names;

}

# get the context file for this URL
sub get_context_file {

    my $this = shift;
    my $type = shift;

    my @context_file_extensions;
    if ( $type ) {
	push @context_file_extensions, ".${type}-context.xml";
    }
    push @context_file_extensions, ".full-context.xml";

    foreach my $context_file_extension (@context_file_extensions) {
	my $file = $this->get_file($this->url2uid($this->{url}) . $context_file_extension);
	if ( $file ) {
	    return $file;
	}
    }

    return undef;

}

# get the requested file
sub get_file {

    my $this = shift;
    my $file_name = shift;
    
    $this->_lock();

    my $full_path = $this->get_data_directory() . "/" . $file_name;

    my $result = undef;
    # check if file exists and return accordingly
    if ( -e $full_path ) {
	$result = $full_path;
    }
    
    $this->_unlock();

    return $result;

}

# create the requested file and return full path
sub create_file {

    my $this = shift;
    my $file_name = shift;

    $this->_lock();

    my $result = $this->get_data_directory() . "/" . $file_name;

    $this->_unlock();

    return $result;

}

# get summaries for this URL and for a given summarizer
sub get_summaries {

    my $this = shift;
    my $summarizer_id = shift;

    $this->_lock();

    # get all the files for this URL and this summarizer
    my $summary_file_names = $this->get_files($url, $summarizer_id);

    # read the content of each summary file found
    my @summaries;
    foreach my $summary_file (@{$summary_files}) {
        local $/ = undef;
        open(SUMMARY_FILE, $summary_file) || next;
        push @summaries, <SUMMARY_FILE>;
        close(SUMMARY_FILE);
    }

    $this->_unlock();

    # return the matching summaries
    return \@summaries;

}

# write a file
sub write_file {

    my $this = shift;
    my $file_name = shift;
    my $file_content = shift;

    $this->_lock();
   
    my $absolute_file_name = $this->get_data_directory() . "/$file_name";
    open (NEW_FILE, "> $absolute_file_name") || die "unable to create file $absolute_file_name in $ENV{PWD}: $!";
    print NEW_FILE "$file_content\n";
    close(NEW_FILE);

    $this->_unlock();

    return $absolute_file_name;

}

sub get_number_of_lines {

    my $filename = shift;

    my $lines = 0;
    open(FILE, $filename) or die "Cannot open '$filename': $!";
    while (sysread FILE, $buffer, 4096) {
        $lines += ($buffer =~ tr/\n//);
    }
    close FILE;

    return $lines;

}

1;
