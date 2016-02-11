package DataManagers::ContentDownloader;

use base ("DataManager");
use Carp;
use WWW::Mechanize;

# type of data produced by this data manager
sub data_type {
    return "content";
}

# download the content of a URL
sub run {
    my $this = shift;
    my $url_obj = shift;
    
    # has the content been downloaded already ?
    if ( $url_obj->{content} ) {
	return 1;
    }
    elsif ( $url_obj->{content} = $this->get_data_from_file($url_obj) ) {
	return 1;
    }

    # we must download the content for this URL
    my $mech = WWW::Mechanize->new();

    my $response = undef;
    eval {
	$response = $mech->get($url_obj->url());
    };

    if ( $mech->success() ) {
	$url_obj->{content} = $mech->content();
	return 1;
    }

    return 0;
}

1;
