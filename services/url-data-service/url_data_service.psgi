use strict;
use warnings;

use FindBin;
use lib "${FindBin::Bin}/../../src/perl/";
use lib "${FindBin::Bin}/../../data/src/";
use lib "${FindBin::Bin}/../../third-party/local/lib/";

use JSON::RPC::Dispatch;

use UrlDataService;

print STDERR ">> loading: url-data service\n";
my $url_data_service = new UrlDataService;

my $router = Router::Simple->new; # or use Router::Simple::Declare
$router->connect( 'global-count' => { handler => $url_data_service , action => 'global_count' } );

my $dispatch = JSON::RPC::Dispatch->new( router => $router );

sub psgi_app {
    my $env = shift;
    $dispatch->handle_psgi( $env );
}

\&psgi_app;
