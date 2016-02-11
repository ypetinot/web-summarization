package EnergyFeatureGenerator;

# TODO: will need to add a post-processor for normalizations, etc. (?)

use strict;
use warnings;

use DMOZ::GlobalData;
use Web::Summarizer::SentenceBuilder;

use FileHandle;
use JSON;

use Moose;

extends 'Category::Operator';

# global data
has 'global_data' => ( is => 'ro' , isa => 'DMOZ::GlobalData' , lazy => 1 , builder => '_build_global_data' );
sub _build_global_data {
    my $this = shift;
    return new DMOZ::GlobalData( data_directory => $this->global_data_directory() , ngram_count_threshold => $this->ngram_count_threshold() );
}

# Assume I don't need this for now
#### global data directory
###has 'global_data_directory' => ( is => 'ro' , isa => 'Str' , required => 1 );

# sentence builder
has 'sentence_builder' => ( is => 'ro' , isa => 'Web::Summarizer::SentenceBuilder' , default => sub { { return new Web::Summarizer::SentenceBuilder() } } );

# ngram orders
has 'ngram_orders' => ( is => 'ro' , isa => 'ArrayRef' , default => sub { [ 1 , 2 , 3 ] } );

sub _process {

    my $this = shift;
    my $instance = shift;

    my $instance_url = $instance->url();

    # instance features
    my %features;
    
    # object
    # TODO ?
    my @object_fields = ( 'content.rendered' , 'title' );

    # summary
    my $summary = $instance->get_field( 'summary.chunked' );
    my $summary_object = $this->sentence_builder()->build( $summary , $instance );

    # TODO: add "has_field" features, so that we don't penalize object that do not have data for a particular field

    # 1 - get summary configuous n-grams and check proportion of appearance in object (one for each modality)
    # TODO: break down / parameterized by frequency of n-grams in reference corpus: top 1% genericity, top 2%, top ... , top 100%
    foreach my $object_field (@object_fields) {

	foreach my $ngram_order (@{ $this->ngram_orders() }) {
	    
	    foreach my $skip_mode (0,1) {

		# generate summary n-grams for the current order
		my $summary_ngrams = $summary_object->get_ngrams( $ngram_order , 1 )->binary();

		# generate field n-grams for the current order
		# TODO: is this the most generic way of building n-grams for a text object ?
		my $object_field_ngrams = $this->sentence_builder->build( $instance->get_field( $object_field ) , $instance )->get_ngrams( $ngram_order , 1 )->binary();

		# compute intersection between summary and object field ==> dot product
		my $ngram_intersection = $object_field_ngrams->project( $object_field_ngrams );

		my $count = $summary_ngrams->manhattan_norm();
		my $overlap_count = $ngram_intersection->manhattan_norm();

=pod		
		# iterate over summary ngrams
		foreach my $summary_ngram (@{ $summary_ngrams }) {
		    
		    # get n_gram genericity
		    # TODO
		    my $summary_ngram_genericity = 0;

		    # check presence in object
		    # TODO: improve ?
		    
		}
=cut
		
		my $feature_key = join( "::" , "so" , $object_field , $ngram_order , $skip_mode );
		my $feature_value = $overlap_count / $count;
		
		$features{ $feature_key } = $feature_value;
		
	    }
	    
	}

    }

    # 2 - what else ???
    # TODO

    # individual joint n-gram indicators (?)
    # should this be abstracted ?
    # Note: probably not a good idea ...

###    my ( $field_data , $mapping , $mapping_surface ) = $instance->get_field( $specific_field_name, 'decode_json' , 1 , 1 );
###    my $global_feature_count = $this->global_data()->global_count( $field , $ngram_order , $feature_key );
    
    # TODO : skip pairs where the summary token matches the feature ? --> No , this is actually informative (extractive behavior)
    # TODO : how can we skip overly frequent summary tokens ? --> tokens that appear in more than 50% of summaries ?
    
    # we only process features that appear a sufficient number of times throughout the corpus 
    # TODO: integrate ngram count threshold in process object
    # TODO: this probably affects the global counts, move this to a later stage ?

    print join( "\t" , $instance_url , map { join( ":" , $_ , $features{ $_ } ) } keys( %features ) ) . "\n";
    
}

###    my $total_count = $this->global_data()->total_occurrences( $field , $ngram_order );
###    my $object_count = $this->global_data()->global_count( $field , $ngram_order , $object );
    
no Moose;

1;
