package WordGraph::ReferenceCollector::CategoryFileCollector;

use strict;
use warnings;

use File::Slurp;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector' );

# category data file
has 'data_file' => ( is => 'ro' , isa => 'Str' , required => 1 );

sub _run {
    
    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    my $category_data_file = $this->data_file;
    my @reference_objects = grep { defined( $_ ) } map {

	chomp;

	my @fields = split /\t/ , $_;
	my $reference_url = shift @fields;
	my $reference_url_normalized = shift @fields;
	my $reference_summary = shift @fields;
	my $reference_category = shift @fields;

	if ( $target_object->url eq $reference_url ) {
	    undef;
	}
	else {
	    $this->_load_object( $reference_url_normalized ,
				 summary => $reference_summary ,
				 category => $reference_category );
	}

    } read_file( $category_data_file );

    return \@reference_objects;

}

__PACKAGE__->meta->make_immutable;

1;
