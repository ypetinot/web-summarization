package Environment;

use strict;
use warnings;

use Module::Path qw/module_path/;
use Path::Class;

use Moose;
use namespace::autoclean;

sub distribution_base_path {

    my $that = shift;

    my $this_path = module_path(__PACKAGE__);
    my $file = file( $this_path );
    my $file_dir = $file->parent;
    my $distribution_base_path = file( $file_dir . '/../../' );

    return $distribution_base_path;

}

sub distribution_path {
    my $that = shift;
    my $sub_directory_name = shift;
    my $distribution_directory_path = join( '/' , $that->distribution_base_path , $sub_directory_name );
    return $distribution_directory_path;
}

# TODO : add code to automatically generate methods given a key => path mapping
sub distribution_bin {
    my $that = shift;
    return $that->distribution_path( "bin" );
}

# TODO : automatically generate based on distribution directories ?
sub summarizers_base {
    my $that = shift;
    return $that->distribution_path( 'summarizers' );
}

sub third_party_base {
    my $that = shift;
    return $that->distribution_path( 'third-party' );
}

sub third_party_local {
    my $that = shift;
    return join( "/" , $that->third_party_base , 'local' );
}

sub third_party_local_bin {
    my $that = shift;
    return $that->distribution_path( 'third-party/local/bin' );
}

sub data_base {
    my $that = shift;
    return $that->distribution_path( 'data' );
}

# TODO : specification of data_base is redundant
sub data_bin {
    my $that = shift;
    return $that->distribution_path( 'data/bin/' );
}

sub data_models_base {
    my $that = shift;
    return $that->distribution_path( 'data/models' );
}

sub summarizer_base {
    my $that = shift;
    my $summarizer_id = shift;
    return $that->distribution_path( "summarizers/${summarizer_id}" );
}

sub evaluation_bin {
    my $that = shift;
    return $that->distribution_path( "evaluation/bin" );
}

__PACKAGE__->meta->make_immutable;

1;
