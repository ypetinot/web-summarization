package NgramCounts;

use strict;
use warnings;

use FileHandle;
use JSON;

use Moose;

extends 'Category::GlobalOperator';

# n-gram orders
has 'ngram_orders' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# n-gram counts
has 'ngram_counts' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

sub _process {

    my $this = shift;
    my $instance = shift;
    my $field = shift;

    foreach my $ngram_order (@{ $this->ngram_orders() }) {

	# TODO: add ngrams access abstraction to UrlData ?
	my $specific_field_name = join( "." , $field , "ngrams" , $ngram_order );
	my ( $field_data , $mapping , $mapping_surface ) = $instance->get_field( $specific_field_name, 'decode_json' , 1 , 1 );
	
	# iterate over field features (should be precomputed)
	foreach my $field_feature (keys( %{ $field_data } )) {
	    
	    my $feature_count = $field_data->{ $field_feature };

	    # TODO: feature mapping should be encapsulated in UrlData ?
	    my $feature_key = $mapping_surface->{ $field_feature };

	    $this->ngram_counts()->{ $field }->{ $feature_key } += $feature_count;
	    
	}
    
    }

}

sub _finalize {

    my $this = shift;
    my $field = shift;

    # 1 - open output file
    my $output_file = $this->get_output_file( $field );

    # 2 - write out ngram counts
    my $field_ngrams = $this->ngram_counts()->{ $field };
    foreach my $ngram_key (keys( %{ $field_ngrams } )) {
	print $output_file join( "\t" , $ngram_key , $field_ngrams->{ $ngram_key } ) . "\n";
    }

    # 3 - close output file
    $output_file->close();

}

no Moose;

1;
