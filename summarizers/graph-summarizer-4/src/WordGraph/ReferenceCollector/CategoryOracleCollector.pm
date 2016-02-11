package WordGraph::ReferenceCollector::CategoryOracleCollector;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector::CategoryIndexCollector' );

sub target_category {
    my $this = shift;
    my $target_object = shift;
    return $target_object->get_field( 'category' , namespace => 'dmoz' );
}

__PACKAGE__->meta->make_immutable;

1;
