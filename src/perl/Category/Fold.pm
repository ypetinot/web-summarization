package Category::Fold;

# Abstracts the notion of fold over the raw category data

# The set of chunks is obtained directly from the Category::Data instance

use strict;
use warnings;

use Moose;
use MooseX::Storage;
use namespace::autoclean;

#with Storage('base' => 'Category::Fold::Storage', 'format' => 'JSON', 'io' => 'File');
with('Logger');
with Storage('format' => 'JSON', 'io' => 'File');

use Category::UrlData;

use JSON;

# fields

# id
has 'id' => (is =>'ro', 'isa' => 'Num', required => 1);

# fold gists (indices)
has 'fold_gists' => (is => 'ro', 'isa' => 'ArrayRef', required => 1);

###### override summaries (gists) field
#####has '+summaries' => (is => 'ro', 'isa' => 'ArrayRef', lazy => 1, init_arg => undef, builder => '_summaries_builder', traits => [ 'DoNotSerialize' ] );

###### override chunks field
#####has '+chunks' => (is => 'ro', 'isa' => 'ArrayRef', lazy => 1, init_arg => undef, builder => '_chunks_builder', traits => [ 'DoNotSerialize' ] );

# category data back pointer
#has 'category_data' => (is => 'ro', isa => 'Category::Data', lazy => 1, required => 0, builder => '_category_data_builder', traits => [ 'DoNotSerialize' ]);
has 'category_data' => (is => 'rw', required => 0, traits => [ 'DoNotSerialize' ]);
# lazy => 1,
# builder => '_category_data_builder',

# split data
has '_fold_test_split' => (is => 'rw', isa => 'ArrayRef', lazy => 1, required => 0, builder => '_fold_test_data_builder', traits => [ 'DoNotSerialize' ]);

# fold/test data builder
sub _fold_test_data_builder {

    my $this = shift;

    my ($fold_data,$test_data) = $this->_data_split();

    return [ $fold_data , $test_data ];

}

# fold data accessor
sub fold_data {

    my $this = shift;

    return $this->_fold_test_split->[ 0 ];
    
}

# test data accessor
sub test_data {

    my $this = shift;

    return $this->_fold_test_split->[ 1 ];
    
}

# build summaries field
sub _summaries_builder {

    my $this = shift;

    my @summaries;
    foreach my $fold_gist (@{ $this->fold_gists() }) {
	push @summaries, $this->category_data()->summaries()->[ $fold_gist ];
    }

    return \@summaries;

}

# build chunks field
sub _chunks_builder {

    my $this = shift;

    my @chunks;

    my @original_chunks = @{ $this->category_data()->chunks() };
    foreach my $original_chunk (@original_chunks) {

	# check that this node does appear in one of the gists in this fold
	if ( ! $this->_is_in_fold( $original_chunk ) ) {
	    next;
	}

	push @chunks, $original_chunk;

    }

    return \@chunks;

}

=pod
# build category data field
sub _category_data_builder {

    my $this = shift;

    # note that this is ok because all data access is done through the chunks/summaries methods
    my $category_data = Category::Data->new( repository => $category_repository , category_data_base => $this->category_data_base() );

    return $category_data;

}
=cut

# get test url data (whatever is not in this fold)
sub _data_split {

    my $this = shift;

    my @fold_url_data;
    my @test_url_data;

    my $category_urls = $this->category_data->urls();
    my $category_url_data = $this->category_data()->url_data();

    my %in_ids;
    map{ $in_ids{ $_ }++; } @{ $this->fold_gists() };

    my @required_fields = ( 'content.rendered' , 'summary' );
    url_loop: for (my $i=0; $i<scalar( keys( %{ $category_url_data } ) ); $i++) {

	my $category_url = $category_urls->[ $i ];
	my $current_url_data = $category_url_data->{ $category_url };

	# we forcefully remove any entry for which page content is missing
	# as this is just creating noise and leading to unfair comparisons between systems
	# (should we make this configurable at some level ?)
	foreach my $required_field (@required_fields) {
	    if ( ! length( $current_url_data->get_field( $required_field ) ) ) {
		$this->error( "($this) Skipping URL $category_url, missing $required_field data ..." );
		next url_loop;
	    }
	}

	if ( defined( $in_ids{ $i } ) ) {
	    push @fold_url_data, $current_url_data;
	}
	else {
	    push @test_url_data, $current_url_data;
	}

    }

    return ( \@fold_url_data , \@test_url_data );

}

# is a particular node appearing somewhere in this fold ?
sub _is_in_fold {

    my $this = shift;
    my $node = shift;

    my $fold_gists = $this->summaries();

    foreach my $fold_gist ( @{ $fold_gists } ) {
	
	foreach my $fold_gist_element (@{ $fold_gist }) {
	    
	    if ( $fold_gist_element == $node->id() ) {

		return 1;

	    }

	}

    }

    print STDERR "Eliminating chunk from category fold: " . $node->get_surface_string() . " / " . $node->id() . "\n";

    return 0;
    
}

# prepare data
sub prepare_data {

    my $this = shift;
    
    my @url_data = values(%{ $this->url_data() });
    foreach my $url_data_entry (@url_data) {
    	$url_data_entry->prepare_data( $this->chunks() );
    }

    return $this;

}

# restore
sub restore {

    my $that = shift;
    my $category_data = shift;
    my $serialized_fold = shift;

    # load fold
    my $fold = $that->thaw( $serialized_fold );

    # set category data
    $fold->category_data( $category_data );

    return $fold;

}

# TODO : remove if the circular dependencies no longer exist (might be the case)
=pod
sub DESTROY {

    my $this = shift;

    $this->category_data( undef );
    $this->_fold_test_split( [] );

#    print STDERR "Destroying fold ($this) ...\n";

}
=cut

__PACKAGE__->meta->make_immutable;

1;
