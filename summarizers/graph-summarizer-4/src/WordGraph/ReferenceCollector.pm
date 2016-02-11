package WordGraph::ReferenceCollector;

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

# ReferenceOperator is a horizontal behavior => not necessarily true ?
with( 'WordGraph::ReferenceOperator' );
with( 'Logger' );

sub _filter_test_builder {

    my $this = shift;

    my $filter_sub = sub {
	my $instance = shift;

	if ( $instance->url eq $this->filter ) {
	    return 1;
	}

	return 0;

    };

    return $filter_sub;

}

sub _serialization_id {
    
    my $this = shift;
    my $reference_object = shift;

    my @parameters = ( $reference_object->url );

    return [ 'reference-raw' , \@parameters ];

}

# TODO : this could even be part of Category::UrlData
method _load_object( $url_normalized , :$summary , :$category ) {

    my $reference_object = Category::UrlData->load_url_data( $url_normalized );
    if ( ! defined( $reference_object ) ) {
	print STDERR "[TODO] all data for $url_normalized should now be removed from the datastore ...\n";
	return undef;
    }
	
    # TODO : this should be removed once the correct indexing is in place
    if ( ! $reference_object->has_field( 'summary' , namespace => 'dmoz' ) ) {
	$reference_object->set_field( 'summary' , $summary , namespace => 'dmoz' );
    }
    if ( ! $reference_object->has_field( 'category' , namespace => 'dmoz' ) ) {
	$reference_object->set_field( 'category' , $category , namespace => 'dmoz' );
    }

    return $reference_object;

}

__PACKAGE__->meta->make_immutable;

1;
