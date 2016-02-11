package Model;

use strict;
use warnings;

# Base class for all (statistical/energy-based) models

# The Model is the function that we want to learn, i.e. the manifold. It is parameterized by feature weights which control the impact of each feature (dimension) on the function's output.
# Note that ideally this class does not correspond to an "unrolled" model for a specific instance, but instead to a list of sub-model types (e.g. factors in a factor graph) that may be replicated by ...

# The Model class is responsible for the following tasks:
# * Conversion of raw data objects into featurized objects ?
# * Maintaining weights associated with each feature used in the representation of featurized objects

use Carp;

use Moose::Role;

sub _id_builder {
    my $this = shift;
    return ref( $this );
}

with('Identifiable','Logger');

# feature weights
has 'feature_weights' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# features
has 'features' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => 'list_features' );

# instance creation is the responsibility of the model
requires('create_instance');

=pod
# input => instance mapper
sub input_instance_adapter {

    my $this = shift;
    my $input = shift;

    # by default this is a no-op
    return $input;

}
=cut

=pod
# instantiate model
sub instantiate {

    my $this = shift;
    my $instance = shift;

    # create instantiated model
    my $instantiated_model = $

}
=cut

# Note : featurize is in fact to be implemented by the "instantiated" model
###requires 'featurize';
=pod
    my @reference_entries;
    foreach my $instance_entry (@{ $instances }) {
	my $instance_object = $instance_entry->[ 0 ];
	push @reference_entries, [ $instance_object , $featurizable_model->featurize_output( $instance_object ) ];
    }
=cut

=pod
# featurize
sub featurize {

    my $this = shift;
    my $instance_in = shift;
    my $instance_out = shift;

    # Make sure the instance we got is effectively an instance of this model
    # TODO : optimize this , using roles ?
###    if ( ref( $instance->model ) ne ref( $this ) ) {
###	croak "Model mismatch ...";
###    }	 

#    my $instance_featurized = $instance->featurize;

    my $instance_featurized = {};

    # iterate over features
    foreach my $feature_id (keys( %{ $this->features } )) {

	my $feature = $this->features->{ $feature_id };
	# CURRENT : instance variables >> model variables >> feature variables ?
	# Mapping (1) is currently achieved by creating a custom class instantiating the model (i.e. $instance)
	# Mapping (2) ...
	my $feature_value = $feature->compute( $instance_mapped );

	$instance_featurized->{ $feature_id } = $feature_value;

    }

    return $instance_featurized;

}
=cut
requires('featurize');

# transform instances - to be overridden by sub-classes if needed
# instance format : [ [ instance_in , instance_out ] , ... ]
sub transform_instances {

    my $this = shift;
    my $instances = shift;

    # TODO : how can we bypass this in cases where transform instance has not been overridden ?
    my @transformed_instances = map {

	my $transformed_instances = $this->transform_instance( $_ );

	# Note : one raw instance may lead to the generation of several "learning instances"
	( ref( $transformed_instances ) eq 'ARRAY' ) ? @{ $transformed_instances } : $transformed_instances;

    } @{ $instances };

    return \@transformed_instances;

}

# 1 - generate instances as expected by the model
# While typical model will simply directly work using the raw instances provided to the manager, it is possible to transform the instances
# appropriate for the learning problem that is modeled by the underlying model.
sub transform_instance {

    my $this = shift;
    my $instance = shift;

    # no-op
    
    return $instance;

}

sub serialize {

    my $this = shift;

    # ************************************************************************************************************************
    # 6 - Write out everything we can !
    # ************************************************************************************************************************
    
    if ( $this->serialization_directory_model ) {
	
	# 6 - 1 - Write out summary graph
###	$summary_graph->serialize( $this->serialization_directory_model );
	
    }

=pod
    # 5 - 2 - Write out model params
    my $params_json = encode_json( $params );
    my $params_file = join("/", $output_directory, $Web::Summarizer::Graph2::Definitions::FILE_PARAMS);
    write_file( $params_file , $params_json );
=cut

}

=pod
#  (default)
# Note : may be overridden by sub-roles (e.g. Decoder::LocalDecoder)
sub cost {
    my $this = shift;
    return $this->loss_function( @_ );
}
=cut

# cost function (must be provided by sub-roles)
requires('cost');

1;
