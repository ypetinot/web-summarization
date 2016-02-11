package Evaluation::Environment;

# abstracts the evaluation environment

use Evaluation::URL;

use Carp;
use Fcntl ':flock'; # import LOCK_* constants
use URI::Escape;
use File::Find;
use File::Path;

# constructor
sub new {

    print STDERR "[Environment] Creating environment ...\n";

    my $this = shift;
    my $package = ref($this) || $this;

    # now extract the arguments
    my $root = shift;
    my $configuration = shift;

    # create lock file
    open(ENVIRONMENT_LOCK, ">>$root/.lock") or die "Can't open environment lock: $!";

    # read in configuration
    if ( $configuration ) {
	local $/ = undef;
	open CONFIGURATION_DATA, $configuration or die "unable to open file $configuration: $!";
	my $configuration_data = <CONFIGURATION_DATA>;
	close CONFIGURATION_DATA;
	eval($configuration_data);
    }

    # set PATH
    $ENV{PATH} .= ":" . $ENV{CONTEXT_SUMMARIZATION_COMMON_ROOT} . "/bin/";

    # ...
    my $hash = {};
    $hash->{_ENVIRONMENT_LOCK} = \*ENVIRONMENT_LOCK;
    $hash->{_ENVIRONMENT_ROOT} = $root;
    $hash->{_urls} = {};
    $hash->{_initialized} = 0;

    bless $hash, $package;

    if ( ! $hash->{_initialized} ) {
	$hash->_init();
    }

    return $hash;

}

# environment initialization
sub _init {
    
    my $this = shift;
    $this->lock();

    if ( $this->{_initialized} ) {
	return; 
    }
    
    print STDERR "[Environment] " . time() . " Initializing environment ...\n";

    my $environment_root = $this->get_root();

    if ( ! -d $environment_root ) {
        croak "Invalid evaluation environment ...";
    }

    $this->_load();

    $this->{_initialized} = 1;
    print STDERR "$$ - environment initialized !\n";

    $this->unlock();

}

# load environment
sub _load {

    my $this = shift;
    
    $this->lock();

    # there is one .url file per registered URL, find all of them
    find( { no_chdir => 0, wanted => sub {

	my $absolute_filename = $File::Find::name;
	my $filename = $_;

	if ( $filename =~ m/^(.+)\.(full|filt)\-context\.xml$/ ) {

	    my $uid = $1;
	    my $url = Evaluation::URL->uid2url($uid);

	    if ( defined($this->{_urls}->{$url}) ) {
		croak "there is more than one instance of $url: $filename and " . $this->{_urls}->{$url};
	    }
	    else {
		$this->{_urls}->{$url} = $absolute_filename;
	    }

	}
    } }, ($this->get_root()));

    $this->unlock();

}

# get environment root
sub get_root {
    my $this = shift;

    return $this->{_ENVIRONMENT_ROOT};
}

# returns list of all URLs
sub getAllURLs {

    my $this = shift;
    
    my @all_urls;

    $this->lock();
    
    @all_urls = keys(%{$this->{_urls}});

    $this->unlock();

    return \@all_urls;

} 

# get entry for the specified URL
sub getURL {

    my $this = shift;
    my $url  = shift;

    if ( !defined($this->{_urls}->{$url}) ) {
	return undef;
    }

    return Evaluation::URL->load($this->{_urls}->{$url}, $this);

}

# check whether the specified URL is available
sub has_url {

    my $this = shift;
    my $url  = shift;

    return defined($this->getURL($url));

}

# register the specified URL
sub register_url {

    my $this = shift;
    $this->lock();

    my $url = shift;

    # normalize url
    # TODO

    # create an entry for this URL
    my $url_entry = new Evaluation::URL($this, url => $url);

    $this->unlock();

    return $url_entry;

}

# lock environment
sub lock {

    my $this = shift;

    flock(*{$this->{_ENVIRONMENT_LOCK}},LOCK_EX);
    # and, in case someone appended
    # while we were waiting...
    seek(*{$this->{_ENVIRONMENT_LOCK}}, 0, 2);


}

# unlock environment
sub unlock {

    my $this = shift;

    flock(*{$this->{_ENVIRONMENT_LOCK}},LOCK_UN);

}

1;
