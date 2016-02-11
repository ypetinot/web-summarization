package WordGraph::ReferenceOperator;

use strict;
use warnings;

use Digest::MD5 qw/md5_hex/;

#use Moose;
use Moose::Role;
#use namespace::autoclean;

# target object
has 'target_object' => ( is => 'rw' , isa => 'Category::UrlData' , trigger => \&target_object_update );

# serialization directory
has 'serialization_directory' => ( is => 'rw' , isa => 'Str' , predicate => 'has_serialization_directory' , required => 0 );

# generic reference filtering (mostly for debugging purposes)
has 'filter' => ( is => 'ro' , isa => 'Str' , required => 0 , predicate => 'has_filter' );
has 'filter_test' => ( is => 'ro' , isa => 'CodeRef' , init_arg => undef , lazy => 1 , builder => '_filter_test_builder' );

sub load {

    my $this = shift;

}

# target object update trigger
sub target_object_update {

    my $this = shift;
    my $new_target_object = shift;
    my $old_target_object = shift;

    # nothing by default;

}

sub run {

    my $this = shift;
    my $target_object = shift;
    my $reference_data = shift;

    # set target object
    $this->target_object( $target_object );

    # serialization path
    my $target_serialization_data = $this->serialization_id( $target_object );

    # check for the existence of a serialization file for this 
    my $full_serialization_path = $this->has_serialization_directory ? join( "/" , $this->serialization_directory , @{ $target_serialization_data } ) : undef;

    # reload existing data / generate reference data
    my $output_data = ( $full_serialization_path && -f $full_serialization_path ) ? $this->_load_reference_entries( $full_serialization_path ) : $this->_run( $target_object , $reference_data , $full_serialization_path );

    if ( $this->has_filter ) {
	my @updated_data = grep { $this->filter_test->( $_ ) } @{ $output_data };
	$output_data = \@updated_data;
    }
    
    return $output_data;
   
}

sub serialization_id {
    
    my $this = shift;
    my $target_object = shift;

    # get key elements from sub-class
    # TODO : is there a better way to return the serializaion id data (i.e. than an array ref ?)
    my ( $key1 , $key2 ) = @{ $this->_serialization_id( $target_object ) };

    return [ $key1 , ref( $key2 ) ? md5_hex( join( "::" , @{ $key2 } ) ) : $key2 ];

}

# TODO : to be removed ?
=pod
sub _load_reference_entries {

    my $this = shift;
    my $filename = shift;

    if ( ! open REFERENCE_CLUSTER_FILE, $filename ) {
	die ">> Unable to open reference cluster file ($filename): $!";
    }
    
    my @reference_entries;

    my %reference_categories;
    my %reference_url_2_reference_category;
    my %reference_url_2_score;
    while ( <REFERENCE_CLUSTER_FILE> ) {
	
	chomp;
	
	my @reference_fields = split /\t/, $_;
	my $reference_url =  shift @reference_fields;
	my $reference_url_category = shift @reference_fields;
	my $reference_url_score = shift @reference_fields;

	if ( ! defined( $reference_categories{ $reference_url_category } ) ) {
	    $reference_categories{ $reference_url_category } = [];
	}
	
	push @{ $reference_categories{ $reference_url_category } } , $reference_url;
	$reference_url_2_reference_category{ $reference_url } = $reference_url_category;
	$reference_url_2_score{ $reference_url } = $reference_url_score;
    }
   
    close REFERENCE_CLUSTER_FILE;

    foreach my $reference_category (keys( %reference_categories )) {
	
	my $reference_urls = $reference_categories{ $reference_category };
	
	# Load reference url data
	my $reference_data = $this->global_data->category_repository->get_url_data( $reference_urls , $reference_category );
	if ( $reference_data ) {
	    push @reference_entries, map { [ $_ , $reference_url_2_score{ $_->url() } ] } @{ $reference_data };
	}

    }
    
    return \@reference_entries;
 
}
=cut

#__PACKAGE__->meta->make_immutable;

1;
