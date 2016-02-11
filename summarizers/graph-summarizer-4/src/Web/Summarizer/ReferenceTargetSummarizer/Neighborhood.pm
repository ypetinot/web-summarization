package Web::Summarizer::ReferenceTargetSummarizer::Neighborhood;

use strict;
use warnings;

use Vector;

use Carp::Assert;
use Function::Parameters qw/:strict/;
use Memoize;

use Moose;
use namespace::autoclean;

with( 'TypeSignature' );

has 'neighbors' => ( is => 'ro' , isa => 'ArrayRef[Category::UrlData]' , required => 1 );

has '_neighbors' => ( is => 'ro' , isa => 'HashRef[Category::UrlData]' , init_arg => undef ,
		      lazy => 1 , builder => '_neighbors_builder' );

# TODO : should this be coming from a role ?
has 'target' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

method prior ( $token , :$ignore = undef , :$all_modalities = 0 ) {

    # TODO : better done using auto dereference ?
    my @selected_neighbors = @{ $self->get_neighbors( $ignore ) };

    my $prior = 0;
    my $n_neighbors = scalar( @selected_neighbors );

    if ( $n_neighbors ) {
	
	foreach my $neighbor (@selected_neighbors) {
	    if ( ! $all_modalities ) {
		$prior += $neighbor->summary_modality->supports( $token ) ? 1 : 0;
	    }
	    else {
		$prior += $neighbor->supports( $token ) ? 1 : 0;
	    }
	}
 
	$prior /= $n_neighbors;

    }

    return $prior;

}

sub get_neighbors {

    my $this = shift;
    my $ignore = shift;

    my @neighbors = @{ $this->neighbors };

    my @selected_neighbors = grep {
	! ( $ignore && ( $_->url eq $ignore->url ) )
    } @neighbors; 
    
    return \@selected_neighbors;

}

# TODO : optimize
sub get_instance {

    my $this = shift;
    my $instance_id = shift;

    my @neighbors = @{ $this->neighbors };

    foreach my $neighbor (@neighbors) {
	if ( $neighbor->url eq $instance_id ) {
	    return $neighbor;
	}
    }
    
    affirm { 0 } "Cannot request an instance that is not part of this neighborhood : $instance_id" if DEBUG;

}

method get_summary_terms ( $ignore = undef , :$check_not_supported = 0 , :$prior_threshold = 0 ) {

    my @selected_neighbors = @{ $self->get_neighbors( $ignore ) };

    my %seen;
    my %summary_terms;
    foreach my $selected_neighbor (@selected_neighbors) {
	
	my $summary_tokens = $selected_neighbor->summary_modality->tokens;
	foreach my $summary_token (keys( %{ $summary_tokens } )) {

	    my $summary_token_object = $summary_tokens->{ $summary_token }->[ 0 ];

	    if ( $summary_token_object->is_punctuation ) {
		next;
	    }

	    my $summary_token_id = $summary_token_object->id;
	    if ( ! defined( $seen{ $summary_token_id } ) ) {
		my $summary_token_prior = $self->prior( $summary_token , ignore => $ignore );
		if ( $summary_token_prior > $prior_threshold ) {
		    if ( ! $check_not_supported || ! $selected_neighbor->supports( $summary_token ) ) {
			$summary_terms{ $summary_token_id } = $summary_token_prior;
		    }
		}
		$seen{ $summary_token_id }++;
	    }
	    
	}

    }

    return \%summary_terms;

}

has 'neighborhood_density' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_neighborhood_density_builder' );
sub _neighborhood_density_builder {
   
    my $this = shift;
    my $ignore = shift;

    # TODO : should we ignore the reference under consideration ?
    my @selected_neighbors = @{ $this->get_neighbors( $ignore ) };

    # compute probability of abstractive terms using kernel density estimation
    my $neighborhood_summary_terms = $this->get_summary_terms;

    my %density;
    my $partition_function = 0;
    foreach my $selected_neighbor (@selected_neighbors) {

	# compute similarity between reference and target
	my $similarity = $this->similarity( $this->target , $selected_neighbor );
	if ( ! $similarity ) {
	    next;
	}
	
	# update partition function
	$partition_function += $similarity;
	
	my $summary_tokens = $selected_neighbor->summary_modality->tokens;
	foreach my $summary_token (keys( %{ $summary_tokens } )) {

	    my $summary_token_object = $summary_tokens->{ $summary_token }->[ 0 ];

	    if ( $summary_token_object->is_punctuation ) {
		next;
	    }

	    my $summary_token_id = $summary_token_object->id;
	    $density{ $summary_token_id } += $similarity;
	    
	}

    }

    # normalize all entries using parition function
    map {
	$density{ $_ } /= $partition_function;
    } keys( %density );

    return \%density;


}

# TODO : the similarity function should become a parameter (specified as a class)
sub similarity {
    my $this = shift;
    my $object_1 = shift;
    my $object_2 = shift;
    return Vector::cosine( map { $_->signature } ( $object_1 , $object_2 ) );
}

has 'type_priors' => ( is => 'ro' , isa => 'Vector' , init_arg => undef , lazy => 1 , builder => '_type_priors_builder' );
sub _type_priors_builder {

    my $this = shift;

    # Note : we use all neighbors but will require relevant types to appear at least twice
    my @selected_neighbors = @{ $this->get_neighbors };

    my %types;
    foreach my $selected_neighbor (@selected_neighbors) {
	
	# TODO : ideally we should look at more than just the named entities, any phrase can be of interest to determine type priors
	#my $summary_utterance = $selected_neighbor->summary_modality->utterance;
	#my $summary_utterance_named_entities = $summary_utterance->named_entities;
	my %_neighbor_named_entities;
	map { 
	    my $entities = $_;
	    foreach my $entity (keys( %{ $entities } )) {
		$_neighbor_named_entities{ $entity }++;
	    }
	} values( %{ $selected_neighbor->named_entities } );
	my @neighbor_named_entities = keys( %_neighbor_named_entities );

	# TODO : we could have a type_signature method in UrlData to take care of this
	my %neighbor_types;

	foreach my $neighbor_named_entity (@neighbor_named_entities) {

	    # determine candidate types for this named entity
	    my $type_signature = $this->type_signature_freebase( lc( $neighbor_named_entity ) );
	    my $type_signature_types = $type_signature->coordinates;
	    foreach my $type_signature_type (keys( %{ $type_signature_types } )) {
		$neighbor_types{ $type_signature_type }++;
	    }

	}

	map {
	    $types{ $_ }++;
	} keys( %neighbor_types );

    }

    # delete type that occurred only once
    my %neighborhood_types;
    my $n_neighbors = scalar( @selected_neighbors );
    map {
	$types{ $_ } / $n_neighbors;
    } grep { $types{ $_ } > 1 } keys( %types );

    # compute distribution ?
    my $neighborhood_type_signature = new Vector( coordinates => \%types );

    return $neighborhood_type_signature;
    
}

memoize( '_mutual_key' );
sub _mutual_key {

    my $this = shift;
    my $instance_1 = shift;
    my $instance_2 = shift;
    
    my $key = join( ':::' , sort { $a cmp $b } map { $_->id } ( $instance_1 , $instance_2 ) );

    return $key;

}

# TODO : should this be serialized at some point ?
has '_pairwise_analyses' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );
method mutual ( $instance_1 , $instance_2 , :$instance_1_threshold = 0 , :$instance_2_threshold) {

    # target_threshold => $self->support_threshold_target , reference_threshold => 1 );

    my $mutual_key = $self->_mutual_key( $instance_1 , $instance_2 );

    if ( ! defined( $self->_pairwise_analyses->{ $mutual_key } ) ) {
	# [ instance_1_specific , instance_2_specific ] 
	# TODO : can we get rid of the target_threshold parameter ? => no notion of target/reference here
	$self->_pairwise_analyses->{ $mutual_key } = $self->extractive_analyzer->mutual( $instance_1 , $instance_2 , target_threshold => $instance_1_threshold , reference_threshold => $instance_2_threshold );
    }
    my $mutual_entry = $self->_pairwise_analyses->{ $mutual_key };

    # TODO : mirrored analysis as a service ?

    return $mutual_entry;

}

# extractive analyzer
has 'extractive_analyzer' => ( is => 'ro' , isa => 'TargetAdapter::Extractive::Analyzer' , init_arg => undef , lazy => 1 , builder => '_extractive_analyzer_builder' );
sub _extractive_analyzer_builder {
    my $this = shift;
    return new TargetAdapter::Extractive::Analyzer;
    #return new TargetAdapter::Extractive::MirroredAnalyzer;
}

__PACKAGE__->meta->make_immutable;

1;
