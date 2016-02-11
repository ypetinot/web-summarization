package WordGraph::ReferenceCollector::CategorySignatureIndexCollector;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use DMOZ::CategorySignatures;

extends( 'WordGraph::ReferenceCollector::CategoryIndexCollector' );

# category signatures
has 'category_signatures' => ( is => 'ro' , isa => 'DMOZ::CategorySignatures' , init_arg => undef , lazy => 1 , builder => '_category_signatures_builder' );
sub _category_signatures_builder {
    my $this = shift;
    return new DMOZ::CategorySignatures;
}

sub target_category {

    my $this = shift;
    my $target_object = shift;

    # CURRENT : 

    # 1 - identify best category
    my $best_category_id = $this->category_signatures->match( $target_object->signature );

    return $best_category_id;

}

__PACKAGE__->meta->make_immutable;

1;
