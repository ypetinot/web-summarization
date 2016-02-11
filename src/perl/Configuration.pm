package Configuration;

use JSON;
use Moose;

# configuration file
has 'configuration_file' => (is => 'ro', isa => 'Str', required => 1, trigger => \&_load);

# all available configurations
has '_configurations' => (is => 'rw', isa => 'HashRef', lazy => 0 );

sub _load {

    my $this = shift;

    my $config = $this->configuration_file();

    my $config_json = undef;

    {
	local $/ = undef;
	open CONFIG_FILE, $config or die "Unable to open config file ($config): $!";
	$config_json = <CONFIG_FILE> ;
	close CONFIG_FILE;
    }

=pod
    my $line = $_;
    if ( $line =~ m/^\#/ ) {
	print STDERR "Skipping commented out configuration entry: $line\n";
	next;
    }
=cut

    # parse JSON config
    my $config_obj = decode_json( $config_json );

    if ( ! $config_obj ) {
	die "Invalid configuration ...";
    }

    my $appearance_models = $config_obj->{ "appearance-models" };
    my $summarizers_specs = $config_obj->{ "models" };

    my %temp_summarizers;
    foreach my $summarizers_spec (keys( %{ $summarizers_specs } )) {
	
	my $spec = $summarizers_specs->{ $summarizers_spec };

	if ( $summarizers_spec =~ m/\*/ ) {

	    foreach my $appearance_model ( keys( %{ $appearance_models } ) ) {
		my $summarizers_spec_copy = $summarizers_spec;
		$summarizers_spec_copy =~ s/\*/$appearance_model/sg;
		my %temp_spec = %{ $spec };
		$temp_spec{ "appearance-model" } = $appearance_model;
		$temp_summarizers{ $summarizers_spec_copy } = \%temp_spec;
	    }

	}
	else {
	    $temp_summarizers{ $summarizers_spec } = $spec;
	}

    }

    # update models
    $config_obj->{ 'models' } = \%temp_summarizers;

    # set _configurations
    $this->_configurations( $config_obj );

}

# TODO: more intelligent implementation to autogenerate methods ?
sub feature_set {

    my $this = shift;
    my $model_key = shift;

    return $this->_configurations()->{ $model_key }->{ 'feature_set' };

}

no Moose;

1;
