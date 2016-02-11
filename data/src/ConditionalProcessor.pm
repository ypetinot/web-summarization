package ConditionalProcessor;

use strict;
use warnings;

use DMOZ::GlobalData;

use FileHandle;
use JSON;
use TokyoCabinet;

use Moose;

extends 'Category::GlobalOperator';

# global data
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , lazy => 1 , builder => '_build_global_data' );
sub _build_global_data {
    my $this = shift;
    return new DMOZ::GlobalData( data_directory => $this->global_data_directory() , ngram_count_threshold => $this->ngram_count_threshold() );
}

# global data directory
has 'global_data_directory' => ( is => 'ro' , isa => 'Str' , required => 1 );

# ngram count threshold
has 'ngram_count_threshold' => ( is => 'ro' , 'isa' => 'Num' , default => 0 );

# chi-square threshold (probably not needed, we should filter at the application level)
has 'chi_square_threshold' => ( is => 'ro' , isa => 'Num' , default => 0 );

# n-gram orders
has 'ngram_orders' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# output directory
has 'output_directory' => ( is => 'ro' , isa => 'Str' , required => 0 );

# joint feature count threshold
has 'joint_count_threshold' => ( is => 'ro' , isa => 'Num' , default => 0 );

# instance count
# TODO: prefiltering ! --> during n-gram generation
has 'instance_count' => ( is => 'rw' , isa => 'Num' , default => 0 );

# output directly to STDOUT instead of maintaining stats in memory
has 'stdout_only' => ( is => 'ro' , isa => 'Bool' , default => 0 );

sub _process {

    my $this = shift;
    my $instance = shift;
    my $field = shift;
    
    # increment instance count
    $this->instance_count( $this->instance_count() + 1 );

    # summary
    my $summary = $instance->get_field( 'summary.chunked' );
    my @summary_tokens = map { my @token_fields = split /\//, $_; \@token_fields; } split /\s+/, $summary;

    foreach my $ngram_order (@{ $this->ngram_orders() }) {

	my $specific_field_key = join( "." , $field , $ngram_order );

	# TODO: add ngrams access abstraction to UrlData ?
	my $specific_field_name = join( "." , $field , "ngrams" , $ngram_order );
	my ( $field_data , $mapping , $mapping_surface ) = $instance->get_field( $specific_field_name, 'decode_json' , 1 , 1 );
	
	print join( "\t" , "__instance__" , $field , $ngram_order , 1 ) . "\n";

	# iterate over field features (should be precomputed)
	foreach my $field_feature (keys( %{ $field_data } )) {

	    my $feature_count = $field_data->{ $field_feature };

	    # TODO: feature mapping should be encapsulated in UrlData ?
	    my $feature_key = $mapping_surface->{ $field_feature };

	    # get global feature count
	    my $global_feature_count = $this->global_data()->global_count( $field , $ngram_order , $feature_key );

	    # skip ignorable features
	    if ( ! $global_feature_count ) {
		next;
	    }

	    foreach my $summary_token (@summary_tokens) {
		
		# TODO : add a more formal normalization step ?
		# Note : only the summary object is normalized, we do not normalize the object features for now (should we ?)
		my $summary_token_surface = lc( $summary_token->[ 0 ] );
		
		if ( ! $this->process_object( 'summary' , 1 , $summary_token_surface ) ) {
		    next;
		}
		
		# TODO : skip pairs where the summary token matches the feature ? --> No , this is actually informative (extractive behavior)
		# TODO : how can we skip overly frequent summary tokens ? --> tokens that appear in more than 50% of summaries ?
	
		# we only process features that appear a sufficient number of times throughout the corpus 
		# TODO: integrate ngram count threshold in process object
		# TODO: this probably affects the global counts, move this to a later stage ?
		if ( $global_feature_count && $global_feature_count > $this->ngram_count_threshold() && $this->process_object( $field , $ngram_order , $feature_key ) ) {
		    
		    if ( ! $this->stdout_only() ) {
			$this->update_batch( $field , [ "raw" ] , [ $ngram_order , $summary_token_surface , $feature_key ] , $feature_count );
			$this->update_batch( $field , [ "raw" , "reference" ] , [ $ngram_order , $summary_token_surface ] , $feature_count );
		    }
		    else {
			print join( "\t" , $field , $ngram_order , $summary_token_surface , $feature_key , $feature_count ) . "\n";
		    }

		}
			
	    }

	}

    }
    
}

# should a particular object be taken into consideration
#memoize("process_object");
sub process_object {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    my $object = shift;

    my $total_count = $this->global_data()->total_occurrences( $field , $ngram_order );
    my $object_count = $this->global_data()->global_count( $field , $ngram_order , $object );
    
    # we do not model summary punctuation
    if ( $object =~ m/^\p{Punct}+$/ ) {
	return 0;
    }

    # TODO: Zipf distribution ?
    ###my $decision = ( $object_count / $total_count ) > 0.01;
    my $decision = ( $object_count > $this->ngram_count_threshold() );

    return $decision;

}

my $separator = "_:_:_";

# update batch
sub update_batch {

    my $this = shift;
    my $field = shift;
    my $domain_data = shift;
    my $key_data = shift;
    my $value = shift;

    my $domain_key = join( $separator , $field , @{ $domain_data } );
    my $key = join( $separator , @{ $key_data } );

    if ( ! defined( $this->batch_data()->{ $domain_key } ) ) {
	$this->batch_data()->{ $domain_key } = {};
    }

    $this->batch_data()->{ $domain_key }->{ $key } += $value;

}

# flush batch
sub _flush_batch {

    my $this = shift;

    foreach my $domain_key (keys( %{ $this->batch_data() } )) {

	my @domain_fields = split /${separator}/, $domain_key;

	foreach my $key (keys( %{ $this->batch_data()->{ $domain_key } } )) {

	    my @key_fields = split /${separator}/, $key;
	    my $value = $this->batch_data()->{ $domain_key }->{ $key };

	    my $output_file_handle = $this->get_output_file( @domain_fields );
	    print $output_file_handle join( "\t" , @key_fields , $value ) . "\n";
	    
	    # is this necessary ?
	    delete $this->batch_data()->{ $domain_key }->{ $key };

	}

    }

}

sub _finalize {

    my $this = shift;
    my $field = shift;

    # nothing for now

}

no Moose;

1;
