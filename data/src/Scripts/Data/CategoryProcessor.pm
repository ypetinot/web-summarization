package Scripts::Data::CategoryProcessor;

use DMOZ::CategoryProcessor;

my $category_file = $ARGV[ 0 ];
my $category_aggregate = 0;

if ( !defined( $category_file ) || ! -f $category_file ) {
    die "Usage: $0 <category-file>"
}

use Moose;
use namespace::autoclean;

has 'processor' => ( is => 'ro' , isa => 'CodeRef' , required => 1 );

has '_category_processor' => ( is => 'ro' , isa => 'DMOZ::CategoryProcessor' , init_arg => undef , lazy => 1 , builder => '_category_processor_builder' );
sub _category_processor_builder {
    my $this = shift;
    return new DMOZ::CategoryProcessor( category_data_file => $category_file , processor => $this->processor );
}

sub run {
    
    my $this = shift;

    # Note : to "run" we simply need to generate the entries associated with this category
    # TODO : is this what we want the semantics of run to be ?
    return $this->_category_processor->entries;

}

__PACKAGE__->meta->make_immutable;

1;
