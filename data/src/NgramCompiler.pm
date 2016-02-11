package NgramCompiler;

use strict;
use warnings;

use Moose;

extends 'Category::GlobalOperator';

# ngram count threshold
has 'count_threshold' => ( is => 'ro' , 'isa' => 'Num' , default => 0 );

# n-gram count
has '_ngram_counts' => ( is => 'ro' , 'isa' => 'HashRef' , default => sub { {} } );

# n-gram surface
has '_ngram_surface' => ( is => 'ro' , 'isa' => 'HashRef' , default => sub { {} } );

sub _process {

    my $this = shift;
    my $instance = shift;
    my $field = shift;

    # data might be corrupted for a few categories - this is not unexpected but should be fixed in the long run
    eval {

	my ( $field_data , $mapping , $mapping_surface ) = $instance->get_field( $field , 'decode_json' , 1 , 1 );
	
	# iterate over field features (should be precomputed)
	foreach my $field_feature (keys( %{ $field_data } )) {
	    
	    # TODO: feature mapping should be encapsulated in UrlData ?
	    my $feature_key = $mapping->{ $field_feature };
	    my $feature_surface = $mapping_surface->{ $field_feature };
	    
	    # update global count
	    $this->_ngram_counts()->{ $field }->{ $feature_key } += $field_data->{ $field_feature };
	    
	    # keep track of surface data
	    $this->_ngram_surface()->{ $field }->{ $feature_key } = $feature_surface;
	    
	}

    };

    if ( $@ ) {
	my $instance_url = $instance->url();
	print STDERR ">> An error occurred while processing instance $instance_url / $field ...\n";
    }

}

sub _finalize {

    my $this = shift;
    my $field = shift;

    # output n-gram data      
    my $field_hash = $this->_ngram_counts()->{ $field };
    my @sorted_keys = sort { $field_hash->{ $b } <=> $field_hash->{ $a } } grep { $field_hash->{ $_ } >= $this->count_threshold() } keys( %{ $field_hash } );
    
    # one line per field n-gram
    foreach my $key ( @sorted_keys ) {
	print join( "\t" , $key , $field_hash->{ $key } , $this->_ngram_surface()->{ $field }->{ $key } ) . "\n";
    }

}

no Moose;

1;
