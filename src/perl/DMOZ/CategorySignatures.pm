package DMOZ::CategorySignatures;

use strict;
use warnings;

use File::Slurp;
use JSON;

use Moose;
use namespace::autoclean;

with( 'Logger' );

# signatures file
has 'signatures_file' => ( is => 'ro' , isa => 'Str' , default => '/proj/nlp/users/ypetinot/data/category.profiles' );

# signatures
has 'signatures' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# dfs
has '_dfs' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# term-2-signatures
has '_term_2_signatures' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_term_2_signatures_builder' );
sub _term_2_signatures_builder {

    my $this = shift;

    my %term_2_signatures;

    $this->logger->info( 'Loading category signatures ...' );
    map {
	
	chomp;
	
	my @fields = split /\t/ , $_;
	my $category_id = $fields[ 0 ];
	my $category_size = $fields[ 1 ];
	my $category_signature_json = $fields[ 2 ];

	my $category_signature = decode_json( $category_signature_json );
	my $category_signature_object = new Vector( coordinates => $category_signature );

	map {

	    my $token = $_;

	    # update term to signatures mapping
	    if ( ! defined( $term_2_signatures{ $token } ) ) {
		$term_2_signatures{ $token } = [];
	    }
	    push @{ $term_2_signatures{ $token } } , [ $category_id , $category_signature_object ];

	    # update dfs
	    $this->_dfs->{ $token }++;


	} keys( %{ $category_signature } );

	$this->signatures->{ $category_id } = $category_signature_object;

    } read_file( $this->signatures_file );
    $this->logger->info( 'Done loading category signatures.' );

    return \%term_2_signatures;

}

sub match {

    my $this = shift;
    my $query_signature = shift;

    # 1 - collect reduced set of category signatures;
    my %query_coordinates = %{ $query_signature->coordinates };
    my @query_signature_coordinates = sort { $query_coordinates{ $b } <=> $query_coordinates{ $a } } keys( %query_coordinates );
    my $max_coordinates = 20;
    if ( scalar( @query_signature_coordinates ) > $max_coordinates ) {
	splice @query_signature_coordinates , $max_coordinates;
    }
    my %matching_categories;
    foreach my $query_signature_coordinate (@query_signature_coordinates) {
	my $category_signatures = $this->_term_2_signatures->{ $query_signature_coordinate };
	my $n_categories = scalar( keys( %{ $this->signatures } ) );
	if ( $category_signatures ) {
	    my $n_category_signatures = scalar( @{ $category_signatures } );
	    if ( $n_category_signatures / $n_categories < 0.25 ) {
		map {
		    $matching_categories{ $_->[ 0 ] }++;
		} @{ $category_signatures };
	    }
	}
    }

    # CURRENT : use tf-idf scoring

    # 2 - compute query/category score for each candidate
    my $best_category_id = undef;
    my $best_category_score = -1;
    my %category_id2score;
    map {
	
	my $category_id = $_;
	my $category_signature = $this->signatures->{ $category_id };
	
	# ***********************************************************************************************************************************************************
	# Note about dfs
	# dfs does not seem to work well on signatures, probably because it is affected by named entities and/or specific terms => does not yield good results
	# CURRENT : dfs relevant only if we manager to remove named entities when computing category signatures
	# TODO : iterative selection until only one candidate remains
#	my $category_score = Vector::cosine( $query_signature , $category_signature , $this->_dfs );
	# ***********************************************************************************************************************************************************

	my $category_score = Vector::cosine( $query_signature , $category_signature );
	
	$category_id2score{ $category_id } = $category_score;

	if ( $category_score > $best_category_score ) {
	    $best_category_id = $category_id;
	    $best_category_score = $category_score;
	}
	
    } keys( %matching_categories );

    my @sorted_categories = sort { $category_id2score{ $b } <=> $category_id2score{ $a } } keys( %category_id2score );
    splice @sorted_categories , 20;

    # 3 - return best category id
    return $best_category_id;

}

# CURRENT :
# 1 - load dmoz summary + categories (without URL data ?)
# 2 - get sample of 50/100 summaries for category and rank by similarity to target signature
# 3 - compute homogeneity of top 20
# 4 - rerank categories

# CURRENT : category score ?

__PACKAGE__->meta->make_immutable;

1;
