use strict;
use warnings;

use FindBin;
use lib "${FindBin::Bin}/../../src/perl/";
use lib "${FindBin::Bin}/../../data/src/";
use lib "${FindBin::Bin}/../../third-party/local/lib/";

use JSON::RPC::Dispatch;

use AppearanceService;

#my $data_directory_base = '/proj/nlp/users/ypetinot/ocelot-working-copy/svn-research/trunk/data/yves-test/';
my $data_directory_base_dev = '/proj/nlp/users/ypetinot/ocelot-working-copy/svn-research/trunk/data/';
my $data_directory_base_prod = '/proj/nlp/users/ypetinot/ocelot/svn-research/trunk/data/';
my $data_directory_base = $data_directory_base_dev;

print STDERR ">> using data directory : $data_directory_base\n";

print STDERR ">> loading: appearance service\n";
my $appearance_service = new AppearanceService( models_base => join( "/" , $data_directory_base , 'models' ) , feature_value_threshold => 5 );
# pre-load the default appearance model
$appearance_service->get_appearance_model( 'default' );

my $router = Router::Simple->new; # or use Router::Simple::Declare
#$router->connect( 'map_appearance_features' => { handler => $appearance_service , action => 'map_appearance_features' } );
$router->connect( 'appearance' => { handler => $appearance_service , action => 'appearance' } );

my $dispatch = JSON::RPC::Dispatch->new( router => $router );

sub psgi_app {
    my $env = shift;
    $dispatch->handle_psgi( $env );
}

\&psgi_app;
