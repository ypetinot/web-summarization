package DMOZ::Mapper::ContentDownloader;

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use LWP;

my $ua = LWP::UserAgent->new;
$ua->agent("Linux Mozilla");

# processing method
sub process {

    my $this = shift;
    my $node = shift;

    my $url = $node->{url};

    my $content = '';

    print STDERR "processing $url\n";

    # Create a request
    my $req = HTTP::Request->new(GET => $url);

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ($res->is_success) {
        $content = $res->content;
    }
    else {
        # print STDERR "failed to download $url: " . $res->status_line . "\n";
    }

    # clean-up --> tidy ?
    # $cleaned_up_context = $response->decoded_content();
    # my $cleaned_up_content = $content;

    # store origin information
    $node->set('content', $content);
  
}

1;

