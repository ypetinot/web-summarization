package Experiments::EMNLP_2015;

# Note : conference shared code is provided as a role => should we do things differently ?

use strict;
use warnings;

use Web::Summarizer::Configuration;

my $separator = $Evaluation::Definitions::SYSTEM_FIELD_SEPARATOR;
my $separator_key_value = $Evaluation::Definitions::KEY_VALUE_SEPARATOR;

use Algorithm::Loops qw(
        Filter
        MapCar MapCarU MapCarE MapCarMin
        NextPermute NextPermuteNum
        NestedLoops
    );
use Carp::Assert;
use Clone qw/clone/;
use Config::JSON;
use JSON;

use Moose::Role;
#use namespace::autoclean

# TODO : is this the best way to specify the precision level ?
sub _precision_builder {
    #return 4;
    return 2;
}

# allow unspecified parameters
has 'allow_unspecified_parameters' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# requested systems
has 'requested_systems' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# meta configuration systems
has 'meta_configuration_systems' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_meta_configuration_systems_builder' );
sub _meta_configuration_systems_builder {
    my $this = shift;
    # TODO : is there a way to manager the meta-configuration using Web::Summarizer::Configuration ?
    return Config::JSON->new( $this->meta_configuration )->config;
}

# systems configuration
# TODO : could we use coercion instead of having a separate attribute ?
has 'meta_configuration' => ( is => 'ro' , isa => 'Str' , required => 1 );

# system entries => built by client object
has 'system_entries' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_system_entries_builder' );

# metrics
# TODO : does this belong here ?
# metrics (keys expected to be found in the output of the system)
has 'metrics' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_metrics_builder' );
sub _metrics_builder {

    my $this = shift;

    my @metrics;

    # TODO : turn into a parameter ?
    #my $max_order = 3;
    my $max_order = 2;

    foreach my $order ( 1 .. $max_order ) {
#	foreach my $weighted (0,1) {
	foreach my $weighted (1) {
	    my $metric_label = "F\-1\/n\=${order}" . ( $weighted ? '/weighted' : '' );
#	    my $metric_label = "P\/n\=${order}" . ( $weighted ? '/weighted' : '' );
	    push @metrics , [ $metric_label , join( "-" , "ngram-prf-fmeasure" , $order , $weighted ) ];
#	    push @metrics , [ $metric_label , join( "-" , "ngram-prf-precision" , $order , $weighted ) ];
	}
    }

    push @metrics , [ 'normalized-lcs' , 'normalized-lcs' ];

    return \@metrics;

}

sub _generate_parameter_key_value_string {
    my $this = shift;
    my $key = shift;
    my $value = shift;
    return join( '=' , $key , $value );
}

sub _generate_system_id {
    my $this = shift;
    return join( '#' , @_ );
}

# Note : a multi-configuration maybe associated with a table, graph, etc.
sub _generate_multi_configuration {

    my $this = shift;
    # TODO : specify using a method parameter => would allow for optional namespaces
    my $namespace = shift;
    my $configuration_manager = shift;
    my $summarizer_entry_base_systems = shift;

    # default to empty hash so we can simply generate a configuration that is the exact replica of the base configuration
    my $summarizer_entry_parameter_ranges = shift || {};

    my @entries;
    for ( my $i = 0; $i < scalar( @{ $summarizer_entry_base_systems } ); $i++ ) {

	my @summarizer_entry_base_system = @{ $summarizer_entry_base_systems->[ $i ] };
	my $base_system = shift @summarizer_entry_base_system;
    
	# 1 - get base configuration
	my $base_configuration = $configuration_manager->get_system_configuration( $base_system );

	my @param_keys;
	my @param_lists;
	
	foreach my $parameter_range_category ( keys( %{ $summarizer_entry_parameter_ranges } ) ) {

	    # TODO : instead of doing this (which is not so bad) can we prevent parameter overriding at the system-configuration level ?
	    my $parameter_range_category_regex = qr/$parameter_range_category/;
	    if ( $base_system =~ m/$parameter_range_category_regex/ ) {
		my $summarizer_entry_parameter_ranges_block = $summarizer_entry_parameter_ranges->{ $parameter_range_category };
		map {
		    push @param_keys, $_;
		    push @param_lists, _generate_param_list( $summarizer_entry_parameter_ranges_block->{ $_ } );
		} keys( %{ $summarizer_entry_parameter_ranges_block } );
	    }

	}

	if ( scalar( @param_lists ) ) {

	    # iterate over param ranges
	    my @list= NestedLoops(
		\@param_lists,
		sub { \@_; },
		);
	    
	    foreach my $list_element (@list) {
		
		# generate summarizer entry
		my ( $summarizer_entry_key , $summarizer_entry ) = $this->_generate_summarizer_entry( $base_configuration , $base_system , \@param_keys , $list_element );
				
		# update unrolled configuration
		push @entries , [ join( '@' , $summarizer_entry_key , @summarizer_entry_base_system ) , $summarizer_entry , \@param_keys , $list_element ];
		
	    }
	
	}
	else {

	    # we run the default configuration for the base system
	    push @entries , [ join( '@' , $base_system , @summarizer_entry_base_system ) , $base_configuration , [] , [] ];

	}

    }

    # TODO : should I clean this up ?
    map { $_->[ 0 ] = join( ':::' , $namespace , $_->[ 0 ] ) , $_ } @entries;
    return \@entries;

}

sub generate_summarizer_systems_entries {

    my $this = shift;

    my @entries;

    my $meta_configuration = $this->meta_configuration_systems;
    my @requested_systems = @{ $this->requested_systems };
    my $summarizers_base_directory = Environment->summarizers_base;
    
    # iterate over base systems
    foreach my $summarizer_entry_id (@requested_systems) {
	
	my $summarizer_entry = $meta_configuration->{ $summarizer_entry_id };
	if ( ! defined( $summarizer_entry ) ) {
	    die "Requested unknown system block : $summarizer_entry_id";
	}

	my $summarizer_entry_handler = $summarizer_entry->{ 'handler' };
	my $summarizer_entry_base_configuration = $summarizer_entry->{ 'base-configuration' };
	my $summarizer_entry_systems = $summarizer_entry->{ 'systems' };
	my $summarizer_entry_parameter_ranges = $summarizer_entry->{ 'parameter-ranges' };

	affirm { defined( $summarizer_entry_handler ) } "must provide a system handler" if DEBUG;

	# generate configurations
	if ( defined( $summarizer_entry_base_configuration ) ) {

	    affirm { defined( $summarizer_entry_systems ) } "must provide a list of systems" if DEBUG;
	
	    # 1 - instantiate configuration
	    my $configuration_manager = new Web::Summarizer::Configuration( file => join( "/" , $summarizers_base_directory , $summarizer_entry_base_configuration ) );
	    
	    # 2 - update configuration based on per-system settings
	    my @ids = map {
		
		my $system_id = $_->{ id };
		my $system_settings = $_->{ configuration_update };
		my $system_analysis_configuration = $_->{ configuration_analysis };
		my $system_sub_id = $_->{ sub_id };

		if ( defined( $system_settings ) ) {
		    $configuration_manager->update_system_settings( $system_id , $system_settings );
		}
		
		my @id_components = ( $system_id );
		if ( defined( $system_sub_id ) ) {
		    push @id_components , $system_sub_id;
		}

		#$system_id;
		\@id_components;

	    } @{ $summarizer_entry_systems };
	    
	    # generate all possible configuration variations for this summarizer
	    my $summarizer_entries = $this->_generate_multi_configuration( $summarizer_entry_id , $configuration_manager , \@ids , $summarizer_entry_parameter_ranges );
	    
	    # write out summarizer entry
	    push @entries , map {
		[ $summarizer_entry_handler , @{ $_ } ];
	    } @{ $summarizer_entries };
	    
	}
	else {
	    
	    # simply write out summarizer entry
	    my $summarizer_entry = [ $summarizer_entry_handler , $summarizer_entry_id ];
	    
	    push @entries , $summarizer_entry;
	    
	}

    }

    return \@entries;

}

sub _generate_param_list {

    my $list_definition = shift;
    
    my $definition_type = ref( $list_definition );
    my $param_list = undef;

    if ( $definition_type eq 'ARRAY' ) {
	$param_list = $list_definition;
    }
    elsif ( $definition_type eq 'HASH' ) {
	
	my @generated_list;

	my $from = $list_definition->{ 'from' };
	my $to = $list_definition->{ 'to' };
	my $step = $list_definition->{ 'step' } || 1;

	for (my $i=$from; $i<=$to; $i=$i+$step) {
	    push @generated_list, $i;
	}

	$param_list = \@generated_list;

    }
    else {
	die "Definition type ($definition_type) is not supported ...";
    }

    return $param_list;

}

sub _generate_summarizer_entry {

    my $this = shift;
    my $base_configuration = shift;
    my $base_system_id = shift;
    my $param_keys = shift;
    my $param_values = shift;

    my $allow_unspecified_parameters = $this->allow_unspecified_parameters;

    # 2 - copy base configuration
    my $copy_configuration = clone( $base_configuration );

    # 3 - configuration key
    my $configuration_key = $base_system_id;

    # 4 - update base configuration
    for (my $i=0; $i<scalar(@{ $param_keys }); $i++) {

	my $param_key = $param_keys->[ $i ];
	my $param_value = $param_values->[ $i ];

	my @param_key_elements = split /\// , $param_key;
	my $target_ref = $copy_configuration;

	my $final_param_key = '';
	while ( scalar( @param_key_elements ) ) {
	    my $next_param_key_element = shift @param_key_elements;

# CURRENT
=pod
	    if ( ! defined( $target_ref->{ $next_param_key_element } ) ) {
		$target_ref->{ $next_param_key_element } = {};
	    }
	    $target_ref = $target_ref->{ $next_param_key_element };
=cut

	    # Note : if allow_unspecified_parameters is on, this only allows for the last parameter path element to be unspecified in the reference configuration
	    if ( ! scalar(@param_key_elements) && ( defined( $target_ref->{ $next_param_key_element } ) || $allow_unspecified_parameters ) ) {
		$target_ref->{ $next_param_key_element } = $param_value;
		# TODO : try to avoid duplication with the corresponding line in the else statement
		$final_param_key .= '/' . $next_param_key_element;
	    }
	    else {

		my $found_param = 0;
		my @_target_ref_keys = keys( %{ $target_ref } );
	      inner_keys: for ( my $i=0; $i<=$#_target_ref_keys; $i++ ) {
		  
		  my $_key = $_target_ref_keys[ $i ];
		  
		  if ( $_key !~ m/$next_param_key_element/ ) {
		      next;
		  }
	  
		  if ( ! defined( $target_ref->{ $_key } ) ) {
		      croak( "Parameter ($next_param_key_element) is unspecified in reference configuration for $base_system_id ..." );
		  }
		  
		  # necessary to gracefully handle regex based replacement, keep track of the actual key being updated
		  $final_param_key .= '/' . $_key;

		  $found_param = 1;
		  $target_ref = $target_ref->{ $_key };
		  
		  last inner_keys;
		  
	      }
		
		if ( ! $allow_unspecified_parameters && ! $found_param ) {
		    croak( "Parameter path ($param_key) cannot be found in reference configuration for $base_system_id ..." );
		}
		
	    }

	}

	# update configuration key
	$configuration_key = join( $separator , $configuration_key , join( $separator_key_value , _map_for_key( $final_param_key ) , _map_for_key( $param_value ) ) );

    }

    return ( $configuration_key , $copy_configuration );

}

sub _map_for_key {

    my $original_string = shift;

    my $mapped_string = $original_string;
    while ( $mapped_string =~ s/_/-/g ) {}
    while ( $mapped_string =~ s/\//\@/g ) {}

    return $mapped_string;
    
}

#__PACKAGE__->meta->make_immutable;

1;
