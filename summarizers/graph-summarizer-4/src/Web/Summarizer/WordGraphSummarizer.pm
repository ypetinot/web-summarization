package Web::Summarizer::WordGraphSummarizer;

use strict;
use warnings;

use Web::Summarizer::Graph2;
use Web::Summarizer::Graph2::Definitions;
use Web::Summarizer::Utils;
use WordGraph;
use WordGraph::Analyzer;
use WordGraph::DataExtractor;
use WordGraph::GraphConstructor::SummaryGraphConstructor;
use WordGraph::GraphConstructor::FilippovaGraphConstructor;
use WordGraph::SentenceBuilder;

use Digest::MD5 qw/md5_hex/;
use File::Path qw/make_path/;
use File::Slurp qw/read_file write_file/;
use Getopt::Long;
use GistTokenizer;
use Graph::Writer::Dot;
use Graph::Writer::XML;
use JSON;
use List::Util qw/max min sum/;
use List::MoreUtils qw/uniq each_array/;
use Pod::Usage;
use POSIX;
use Statistics::Basic qw(:all);

#use Moose;
use Moose::Role;
#use namespace::autoclean;

with('Web::Summarizer::ReferenceTargetSummarizer');

### # Model can range from simple EdgeCost (i.e. for a word-graph) to a ReferenceTargetModel
### with('WordGraph::Decoder','WordGraph::Model');

# TODO : create a model for Filippova algorithms ?

# TODO : turn word-graph into model ? create space concept ?
# Note : the model must be a sub-class of ReferenceTargetModel (this is the basic assumption behind the use of a Word-Graph summarizer)
    
=pod
# 5 - 3 - Write out reference paths
    print STDERR "\tWriting out reference paths and features ...\n";
    my $output_file_paths = join("/", $output_directory, "paths");
    my $output_file_features = join("/", $output_directory, "features");
    open OUTPUT_FILE_FEATURES, ">$output_file_features" or die "Unable to create features file ($output_file_features): $!";
    open OUTPUT_FILE_PATHS, ">$output_file_paths" or die "Unable to create paths file ($output_file_paths): $!";
    foreach my $reference_path (@reference_entries) {
    
    my $reference_url = $reference_path->[0];
    my $reference_sequence = $reference_path->[1];
    my $reference_entry = $reference_path->[2];
    
    print OUTPUT_FILE_PATHS join("\t", $reference_url , grep{ defined( $_ ); } @{ $reference_sequence }) . "\n";
    
    }
    close OUTPUT_FILE_PATHS;
    close OUTPUT_FILE_FEATURES;
=cut

=pod
# 5 - 4 - Write out feature definitions
    print STDERR "\tWriting out feature definitions ...\n";
my $output_file_features_definition = join("/", $output_directory, "features.definition");
open OUTPUT_FILE_FEATURES_DEFINITION, ">$output_file_features_definition" or die "Unable to create features definition file ($output_file_features_definition): $!";
foreach my $feature_name (keys( %feature2id )) {
    print OUTPUT_FILE_FEATURES_DEFINITION join("\t", $feature_name, $feature2id{ $feature_name }) . "\n";
}
close OUTPUT_FILE_FEATURES_DEFINITION;

# 5 - 5 - Write out feature types
my $output_file_feature_types = join("/", $output_directory, "features.types");
open OUTPUT_FILE_FEATURE_TYPES, ">$output_file_feature_types" or die "Unable to create feature types file ($output_file_feature_types): $!";
foreach my $edge_feature (@{ $edge_features }) {
    print OUTPUT_FILE_FEATURE_TYPES join("\t", $edge_feature) . "\n";
}
close OUTPUT_FILE_FEATURE_TYPES;
=cut

# TODO : decoding should trigger slot node expansion, even for non-learning-based decoders (i.e. Filippova's)

# *****************************************************************************************************************************
# 0 - configurations
# *****************************************************************************************************************************
sub _build_configurations {

    my $this = shift;

    my %systems;
    
    if ( ! $this->has_system_configuration && ! -f $this->configuration ) {    
	die "Please provide a configuration file ...";
    }
    
    if ( ! $this->has_system_configuration ) {
        #%systems = %{ JSON->new->relaxed()->decode( read_file( $configuration ) ) };
	my $all_systems = decode_json( read_file( $this->configuration ) );
	map { $systems{ $_ } = $all_systems->{ $_ } } grep { ! defined( $this->system ) || ( $this->system eq $_ ) } keys( %{ $all_systems } );
    }
    else {
	%systems = %{ { $this->system => decode_json( $this->system_configuration ) } };
    }


}

# TODO (?) : post slotting (to group slots for which context may vary) ?

my %frequencies;

sub _find_slot_candidates {
    
    my $path_entries = shift;
    
    my %directed_pairs;
    
    # 1 - scan all entries and keep track of directed pairs, appearance counts and separating paths
    foreach my $path_entry (@{ $path_entries }) {
	
	my $path_id = $path_entry->[ 0 ];
	my $path_sequence = $path_entry->[ 1 ];
	
	my $string_token_count = scalar(@{ $path_sequence });
	
	for (my $i=0; $i<$string_token_count; $i++) {
	    
	    # Note: largest separation length is at least 1 and no more than 25% the length of the associated gist
	    for ( my $j=$i+2; ( ( $j<$string_token_count ) && ( ( $j - $i ) < 0.25 * $string_token_count ) ); $j++ ) {
		
		my $token1 = $path_sequence->[ $i ];

		my $pair_key = join("::", $path_sequence->[ $i ], $path_sequence->[ $j ]);

		if ( ! defined( $directed_pairs{ $pair_key } ) ) {
		    $directed_pairs{ $pair_key } = {
			'from' => $path_sequence->[ $i ],
			'to'   => $path_sequence->[ $j ],
			'paths' => []
		    };
		}
		
		my @copy = @{ $path_sequence };
		my @path = splice @copy , ($i+1), ($j-$i-1);
		push @{ $directed_pairs{ $pair_key }->{ 'paths'} }, [$path_id , $i , $j , \@path];

	    }

	}
       
    }

    # Remove pairs that occur only once
    foreach my $pair_key (keys(%directed_pairs)) {
	if ( scalar( @{ $directed_pairs{ $pair_key }->{ 'paths' } } ) <= 1 ) {
	    delete $directed_pairs{ $pair_key };
	}
    }

    # Filtering
    foreach my $pair_key (keys(%directed_pairs)) {

	my $pair_data  = $directed_pairs{ $pair_key };
	my $pair_from  = $pair_data->{ 'from' };
	my $pair_to    = $pair_data->{ 'to' };
	my $pair_paths = $pair_data->{ 'paths' };

	my %variations2seen;
	my @variations = grep { defined( $_ ); } map {
	    my $variation_key = join(" ", @{ $_->[ 3 ] });
	    if ( defined( $variations2seen{ $variation_key } ) ) {
		undef;
	    }
	    else {
		$variations2seen{ $variation_key } = 1;
		$_;
	    }
	} @{ $pair_paths };

	my $keep_pair = 1;

	# Remove pairs for which there is only one intervening path
	if ( scalar(@variations) < 3 ) {
	    $keep_pair = 0;
	}
	else {

	    # Average frequency of intermediate terms, must be lower than surrounding terms
	    my @frequency_maxima;
	    foreach my $variation (@variations) {
		
		my $frequency_sum = 0;
		my $frequency_maximum = max( map { $frequencies{ _normalized($_) }; } @{ $variation->[ 3 ] } );
		
		push @frequency_maxima, $frequency_maximum;
		
	    }
	    my $pair_intervening_path_frequency_max = max( @frequency_maxima );
	    my $from_frequency = $frequencies{ _normalized($pair_from) };
	    my $to_frequency = $frequencies{ _normalized($pair_to) };
	    if ( 
		( ( $pair_from ne $Web::Summarizer::Graph2::Definitions::NODE_BOG ) && ( $pair_intervening_path_frequency_max >= $from_frequency ) ) ||
		( ( $pair_to ne $Web::Summarizer::Graph2::Definitions::NODE_EOG ) && ( $pair_intervening_path_frequency_max >= $to_frequency ) )
		) {
		$keep_pair = 0;
	    }
   
	}
	
	if ( ! $keep_pair ) {
	    delete $directed_pairs{ $pair_key };
	}
	else {
	    # set target length for slot location
	    $directed_pairs{ $pair_key }->{ 'length' } = median( map { length( @{ $_ } ) } @variations );
	}

    }
        
    # Move additional filtering steps here ?
    # TODO
    
    return \%directed_pairs;

}

#__PACKAGE__->meta->make_immutable;

1;
