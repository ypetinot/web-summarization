package WordGraph::ReferenceCollector::CategoryIndexCollector;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector::IndexCollector' );
with( 'MongoDBAccess' );

sub _solr_collection_builder {
    return 'odp-index-new';
#    return 'odp-index';
}

sub _run {
    
    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    my $target_url = $target_object->url;
    
    # 1 - identify the DMOZ category for the target URL
    my $target_category = $this->target_category( $target_object );

    if ( ! defined( $target_category ) ) {
	die "Missing category data for : $target_url";
    }

    # 2 - retrieve all members of this category
    return $this->_query_solr( 'category:"' . $target_category . '"' , max => 20 );

}
