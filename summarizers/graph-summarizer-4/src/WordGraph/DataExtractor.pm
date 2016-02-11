package WordGraph::DataExtractor;

use strict;
use warnings;

use Memoize;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

extends 'Web::Summarizer::DataExtractor';

# per-instance fillers
has '_fillers_cache' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

memoize('frequency');
sub frequency {

    my $this = shift;
    my $instance = shift;
    my $token_string = shift;

    # load descriptive content for the target instance
    my $descriptive_content = $this->collect_instance_descriptive_content( $instance );

    # _normalized ?
    return $descriptive_content->{ lc( $token_string ) };

}

# collect all possible fillers for a given instance
sub collect_instance_fillers {

    my $this = shift;
    my $instance = shift;

    my $instance_url = $instance->url();

    if ( ! defined( $this->_fillers_cache()->{ $instance_url } ) ) {

	my %candidate_fillers;
	my $descriptive_content = $this->collect_instance_descriptive_content( $instance , 2 );

	map {

	    my $feature_surface = $_;
	    my $predicted_type = '';
	    
	    if ( ! defined( $candidate_fillers{ $feature_surface } ) ) {
		$candidate_fillers{ $feature_surface } = [];
	    }
	    push @{ $candidate_fillers{ $feature_surface } } , [ $feature_surface , $descriptive_content->{ $_ } ]; 

	} keys( %{ $descriptive_content } );
		
        # ranking --> by number of modalities and low number of occurrences in each modality
	my @sorted_candidate_fillers = sort { scalar( @{ $candidate_fillers{ $b } } ) <=> scalar( @{ $candidate_fillers{ $a } } ) } keys( %candidate_fillers );
	
# Probably isn't necessary anymore, this sounds too arbitrary	
###     # only consider top 10 --> definitely an upper bound on the number of filler for any gist !
###	my $candidate_limit = 10;
###	if ( scalar( @sorted_candidate_fillers ) > $candidate_limit ) {
###	    splice @sorted_candidate_fillers, $candidate_limit;
###	}
	
	my @selected_fillers = @sorted_candidate_fillers;
	
	# cache selected fillers
	$this->_fillers_cache()->{ $instance_url } = \@selected_fillers;
	
    }
    
    return $this->_fillers_cache()->{ $instance_url };
    
}

# generate features --> must be generated from non-segmented content
sub generate_filler_features {

    my $this = shift;
    my $instance = shift;
    my $candidate = shift;

    my @fields = @{ $instance->modalities() };

    my %features;
    my %appearance_counts;

    foreach my $field (@fields) {
	
	# load field
	my $modality_content = $instance->get_field( $field );
	
	while ( $modality_content =~ m/\W\Q$candidate\E\W/sig ) {
	    $appearance_counts{ $field }++;
	}

	if ( $appearance_counts{ $field } ) {
	    
	    my $appearance_key = join("::" , $field , "appearance" );
	    $features{ $appearance_key } = $appearance_counts{ $field };
		
	    while ( $modality_content =~ m/(\w+)\W\Q$candidate\E\W(\w+)/sig ) {
		
		my $context_pre = lc( $1 || '' );
		my $context_post = lc( $2 || '' );
		
		$features{ join("::", $appearance_key, "context::${context_pre}::${context_post}") }++;
		
	    }

	}

    }

    return \%features;

}

__PACKAGE__->meta->make_immutable;

1;
