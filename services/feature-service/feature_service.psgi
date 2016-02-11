use strict;
use warnings;

use FindBin;
use lib "${FindBin::Bin}/../../src/perl/";
use lib "${FindBin::Bin}/../../data/src/";
use lib "${FindBin::Bin}/../../third-party/local/lib/";

use JSON::RPC::Dispatch;

use FeatureService;

#my $data_directory_base = '/proj/nlp/users/ypetinot/ocelot-working-copy/svn-research/trunk/data/yves-test/';
my $data_directory_base_dev = '/proj/nlp/users/ypetinot/ocelot-working-copy/svn-research/trunk/data/';
my $data_directory_base_prod = '/proj/nlp/users/ypetinot/ocelot/svn-research/trunk/data/';
my $data_directory_base = $data_directory_base_dev;

print STDERR ">> using data directory : $data_directory_base\n";

# TODO : create base class for all services and move log messages there ?
print STDERR ">> loading: feature service\n";
my $feature_service = new FeatureService( data_directory_base => $data_directory_base );

my $router = Router::Simple->new; # or use Router::Simple::Declare
$router->connect( 'get_word_entry' => { handler => $feature_service , action  => 'get_word_entry' } );
$router->connect( 'get_word_semantics' => { handler => $feature_service , action  => 'get_word_semantics' } );
$router->connect( 'get_conditional_features' => { handler => $feature_service , action => 'get_conditional_features' } );

my $dispatch = JSON::RPC::Dispatch->new( router => $router );

sub psgi_app {
    my $env = shift;
    $dispatch->handle_psgi( $env );
}

\&psgi_app;
