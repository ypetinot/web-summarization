package Web::Summarizer::Configuration;

use strict;
use warnings;

use Clone qw/clone/;
use Config::JSON;

use Moose;
use namespace::autoclean;

# configuration file
has 'file' => ( is => 'ro' , isa => 'Str' , required => 1 );

# core configuration object
has '_configurations' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_configurations_builder' );
sub _configurations_builder {

    my $this = shift;

    my $file_location = $this->file;

    if ( ! length( $file_location ) || ! -f $file_location ) {
	return undef;
    }
    
    # TODO : directly accessing config is a bit of hack
    my $system_configurations = Config::JSON->new( $file_location )->config;
    
    return $system_configurations;

}

# all resolved configurations
has '_system_configurations' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , default => sub { {} } );

sub get_system_configuration {

    my $this = shift;
    my $system_id = shift;

    if ( ! defined( $this->_system_configurations->{ $system_id } ) ) {

	my $system_configuration = $this->_load_configuration( $system_id );
	if ( ! defined( $system_configuration ) ) {
	    die "Unable to locate system configuration for $system_id in configuration file " . $this->file . " ...";
	}

	$this->_system_configurations->{ $system_id } = $system_configuration;

    }
    
    return $this->_system_configurations->{ $system_id };

}

sub _load_configuration {

    my $this = shift;
    my $system_id = shift;

    my $system_configurations = $this->_configurations;
    my $base_key = 'base';

    my $system_configuration = $system_configurations->{ $system_id };
    my $system_configuration_base = $system_configuration->{ $base_key };
    if ( defined( $system_configuration_base ) ) {
	my $current_configuration_clone = clone( $system_configuration );
	delete( $current_configuration_clone->{ $base_key } );
	$system_configuration = $this->_merge_configuration( $this->get_system_configuration( $system_configuration_base ) , $current_configuration_clone );
    }

    return $system_configuration;

}

sub _merge_configuration {

    my $this = shift;
    my $base_configuration = shift;
    my $extended_configuration = shift;

    # 1 - make copy of base configuration
    my $configuration = clone( $base_configuration );

    # 2 - apply extended configuration on top of the base configuration
    map {
	$this->_merge_configuration_entry( $configuration , $extended_configuration , $_ );
    } keys( %{ $extended_configuration } );

    return $configuration;

}

sub _merge_configuration_entry {

    my $this = shift;
    my $current = shift;
    my $override = shift;
    my $key = shift;

    my $current_value = $current->{ $key };
    my $override_value = $override->{ $key };

    if( ref( $current_value ) && ref( $override_value ) ) {
	foreach my $override_value_key ( keys( %{ $override_value } ) ) {
	    $this->_merge_configuration_entry( $current_value , $override_value , $override_value_key );
	}
    }
    else {
	$current->{ $key } = $override_value;
    }

}

# TODO : should this done at build time instead ?
sub update_system_settings {

    my $this = shift;
    my $system_id = shift;
    my $system_settings = shift;

    # 1 - load system base configuration
    my $system_configuration = $this->get_system_configuration( $system_id );

    # 2 - update system configuration
    my $merged_configuration = $this->_merge_configuration( $system_configuration , $system_settings );

    # 3 - set configuration
    # TODO : should we create a primitive for setting a system's configuration ?
    $this->_system_configurations->{ $system_id } = $merged_configuration;

    return $merged_configuration;

}

__PACKAGE__->meta->make_immutable;

1;
