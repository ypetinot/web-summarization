package NPModel::Base;

# TODO : rename to something that conveys the idea of object classification/labeling model
# TODO : there seems to be a lot overlap with the more generic learning framework I recently introduced

use strict;
use warnings;

use Moose;
use MooseX::Storage;
use namespace::autoclean;

with Storage('format' => 'JSON', 'io' => 'File');

use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Path qw/make_path remove_tree/;

our $CLASS_LABEL = 'class';

# ********************************************************************************* #
# fields

# id
has 'id' => ( is => 'ro' , isa => 'Str' );

# bin root (for shell executions)
has 'bin_root' => (is => 'ro' , isa => 'Str');

# base directory
has 'base_directory' => (is => 'rw' , isa => 'Str');

# description for this model
has 'description' => (is => 'ro', isa => 'Str', required => 1);

# feature names (internal)
# TODO: move this to a FeatureGenerator class ?
has '_feature_names' => ( is => 'rw' , isa => 'HashRef' , lazy => 1 , builder => '_feature_names_builder' );
sub _feature_names_builder {

    my $this = shift;
    my $labels = shift;
    
    # generate features (needs to be done only once)
    my @_feature_sets = @{ $this->contents_featurized };
    
    # remove features that are unique to an instance
    # TODO: abstract this step using a FeatureSelector class
    my %feature2df;
    foreach my $_feature_set (@_feature_sets) {
	map { $feature2df{$_}++; } (keys(%{$_feature_set}));
    } 
    
    my $index = 0;
    
    # generate list of feature names
    my %feature_names;
    map { $feature_names{ $_ } = $index++; } grep { $feature2df{$_} > 2 } keys( %feature2df );

    return \%feature_names;

}

# labels (internal)
has '_labels' => ( is => 'rw' , isa => 'HashRef' , default => sub { my %hash = ( $CLASS_LABEL => 0 );  return \%hash; } );

# features to be generated for each input modality (configuration)
has 'features' => (is => 'ro', isa => 'HashRef', required => 0);

# contents for all the modalities to be featurized
has 'contents' => ( is => 'ro' , isa => 'ArrayRef[Category::UrlData]' , required => 0 , traits => ['DoNotSerialize'] ); 

# featurized contents (objects)
has 'contents_featurized' => ( is => 'ro' , isa => 'ArrayRef' , lazy => 1 , builder => '_contents_featurized_builder' , traits => ['DoNotSerialize'] );
sub _contents_featurized_builder {
    my $this = shift;
    my @_feature_sets;
    foreach my $instance ( @{ $this->contents() } ) {
	my $instance_features = $instance->featurize( $this->features() );
	push @_feature_sets, $instance_features;
    }
    return \@_feature_sets;
}

# ********************************************************************************* #

# initialize instance
sub initialize {

    my $this = shift;
    my $feature_set = shift;
    my $labels = shift;

    # create base dir (if needed)
    make_path($this->base_directory);

    # reset instance
    if ( defined( $labels ) ) {
	$this->reset( $feature_set , $labels );
    }

}

# get feature set
sub get_feature_set {

    my $this = shift;
    
    return $this->_feature_names();

}

# get base file path prefix for all files comprising this model
sub get_model_base {

    my $this = shift;
    
    return join("/", $this->base_directory(), $this->get_model_id());

}


# get model id
sub get_model_id() {

    my $this = shift;
    
    return join("-", ref($this), $this->id || md5_hex( $this->features() ));

}

# get model file
sub get_model_file {

    my $this = shift;
    my $extension = shift;

    return join(".", $this->get_model_base(), $extension);

}

# finalize model
sub finalize {

    my $this = shift;
    
    # nothing by default

}

sub train {

    my $this = shift;
    my $ground_truths = shift;

    # train underlying classifier
    return $this->_train( $this->contents_featurized , $ground_truths );

}


sub write_out {
    my $this = shift;
}

__PACKAGE__->meta->make_immutable;

1;
