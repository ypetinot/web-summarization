package DataManagers::ContextDownloader;

use base ("DataManager");
use Carp;

# type of data produced by this data manager
sub data_type {
    return "context";
}

# aqcuire the context of a URL
sub run {
    my $this = shift;
    my $url_obj = shift;
    
    # has the context been downloaded already ?
    if ( $url_obj->{context} ) {
        return 1;
    }

    my $temp = $this->get_data_from_file($url_obj);
    if ( ! defined($temp) ) {
	$temp = `get-context-urls '$url_obj'`;
    }

    # common processing
    my @temp_context = map { chomp; $_ } split(/\n/, $temp);
    $url_obj->{context} = \@temp_context;

    return 1;
}

1;
