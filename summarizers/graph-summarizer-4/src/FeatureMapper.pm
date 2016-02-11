package FeatureMapper;

use strict;
use warnings;

use File::Slurp;
use Function::Parameters qw/:strict/;
use JSON;

use Moose;
use namespace::autoclean;

with( 'Logger' );

# training/testing mode
has 'training' => ( is => 'ro' , isa => 'Bool' , default => '0' );

# feature mapping
has '_feature2id' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_feature2id_builder' );
sub _feature2id_builder {
    my $this = shift;
    my $feature_mapping_file = $this->feature_mapping_file;
    if ( -f $feature_mapping_file ) {
	# a feature mapping exists
	return decode_json( read_file( $feature_mapping_file ) );
    }
    elsif ( ! $this->training ) {
	die "Feature mapping file does not exist: $feature_mapping_file";
    }
    return {};
}

=pod
# features mapping file
has 'features_mapping_file' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_features_mapping_file_builder' );
method _features_mapping_file_builder => sub {
    my $this = shift;
    return $this->_get_model_file( 'features.mapping' );
};
=cut

# feature mapping filename
has 'feature_mapping_file' => ( is => 'ro' , isa => 'Str' , required => 1 );

sub write_feature_mapping {

    my $this = shift;
    
    local $/;
    open my $fh, '>', $this->feature_mapping_file;
    print $fh encode_json( $this->_feature2id );
    close $fh;

}

# feature count
has '_feature_count' => (
      traits  => ['Counter'],
      is      => 'ro',
      isa     => 'Num',
      default => 0,
    handles => {
	inc_feature_counter   => 'inc',
	dec_feature_counter   => 'dec',
	reset_feature_counter => 'reset',
    },
);

sub register_feature {
    
    my $this = shift;
    my $feature_key_raw = shift;

    if ( ! defined( $this->_feature2id->{ $feature_key_raw } ) ) {
	$this->_feature2id->{ $feature_key_raw } = $this->inc_feature_counter;
    }
    my $feature_key_mapped = $this->_feature2id->{ $feature_key_raw };

    return $feature_key_mapped;

}

# TODO : combine with register_feature ?
sub map_feature_key {

    my $this = shift;
    my $feature_key_raw = shift;

    return $this->_feature2id->{ $feature_key_raw };

}

sub map_features {

    my $this = shift;
    my $features = shift;

    my %mapped_features;
    map {
	my $feature_key_raw = $_;
	my $feature_key = $this->map_feature_key( $feature_key_raw );
	my $feature_value = $features->{ $_ };
	if ( defined( $feature_key ) ) {
	    $mapped_features{ $feature_key } = $feature_value;
	}
	else {
	    $this->logger->warn( "Attempting to map unknown feature key : $feature_key_raw" );
	}
    } keys( %{ $features } );
    
    return \%mapped_features;

}

__PACKAGE__->meta->make_immutable;

1;
