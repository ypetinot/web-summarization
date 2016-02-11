package Vector;

use strict;
use warnings;

use List::Util qw/min/;
#use PerlX::Assert; #-check;
no Carp::Assert;

use Moose;
use MooseX::Storage;
use namespace::autoclean;

with( 'Logger' );
with Storage('format' => 'JSON', 'io' => 'File');
#with Storage('format' => 'Storable', 'io' => 'File');

# coordinates
has 'coordinates' => (
    is => 'rw',
    traits  => ['Hash'],
    isa => 'HashRef',
    default => sub { {} },
    handles => {
	get => 'get',
	set => 'set',
	coordinate_keys => 'keys'
    }
    );

## # json converter
## has '_json' => ( is => 'ro' , isa => 'Ref' , default => sub { my $json = JSON->new->allow_blessed(1) ; } );

# norm
sub norm {

    my $this = shift;

    my $squared_norm = 0;
    map { $squared_norm += $this->coordinates->{ $_ } ** 2; } keys( %{ $this->coordinates } );
    
    return sqrt( $squared_norm );

}

# manhattan norm
sub manhattan_norm {

    my $this = shift;

    my $temp_norm = 0;
    map { $temp_norm += $_ } values( %{ $this->coordinates } );

    return $temp_norm; 

}

# clone
# TODO: does Moose support cloning ?
sub clone {

    my $this = shift;

    my %coordinates_copy = %{ $this->coordinates };
    return __PACKAGE__->new( coordinates => \%coordinates_copy );

}

# scale
sub scale {

    my $this = shift;
    my $coefficient = shift;

    my $result = $this->clone;

    map {
	$result->coordinates->{ $_ } *= $coefficient;
    } keys( %{ $this->coordinates } );

    return $result;

}

# add two vectors
sub add {

    my $this = shift;
    my $vector = shift;
    my $do_clone = shift;

    my $result;
    if ( $do_clone ) {
	$result = $this->clone;
    }
    else {
	$result = $this;
    }

    map {
	$result->coordinates->{ $_ } += $vector->coordinates->{ $_ };
    } keys( %{ $vector->coordinates } );

    return $result;

}

# distance between two vectors
sub substract {

    my $this = shift;
    my $vector = shift;

    return $this->add( $vector->scale( -1 ) );

}

# TODO : this function should probably return a new Vector (i.e. the Vector class should be immutable => faster)
# normalize
sub normalize {

    my $this = shift;
    
    # norm
    my $norm = $this->norm;

    if ( $norm && ( $norm != 1 ) ) {
	map { $this->coordinates->{ $_ } /= $norm } keys( %{ $this->coordinates } );
	affirm { $this->norm - 1 < 0.000001 } "after normalization, norm should be (almost) equal to 1";
    }

    return $this;

}

sub project {
    
    my $this = shift;
    my $onto_vector = shift;

    my %projected_coordinates;
    if ( defined( $onto_vector ) ) {
	my $reference_coordinates = $onto_vector->coordinates;
	map { $projected_coordinates{ $_ } = $reference_coordinates->{ $_ } * ( $this->coordinates->{ $_ } || 0 ) } keys( %{ $reference_coordinates } );
    }

    return new Vector( coordinates => \%projected_coordinates );

}

sub dot_product {

    my $vector1 = shift;
    my $vector2 = shift;

    # TODO : what's the meaning of this ?
    my $dfs = shift || {};

    my $dot_product = 0;
    map { $dot_product += ( ($vector1->get( $_ ) || 0) * ($vector2->get( $_ ) || 0) ) / ( ( $dfs->{ $_ } || 1 )**2 ); } $vector1->coordinate_keys;

    return $dot_product;

}

sub cosine {

    my $vector1 = shift;
    my $vector2 = shift;
    my $dfs = shift;

    my %all_tokens;
    map { $all_tokens{$_} += $vector1->get( $_ ); } $vector1->coordinate_keys;
    map { $all_tokens{$_} += $vector2->get( $_ ); } $vector2->coordinate_keys;

    my $cosine = 0;

    if ( scalar( $vector1->coordinate_keys ) && scalar( $vector2->coordinate_keys ) ) {

	my $dot_product = Vector::dot_product( $vector1 , $vector2 , $dfs );

	my $norm1 = 0;
	map { $norm1 += ( $vector1->get( $_ ) || 0 ) ** 2; } keys(%all_tokens);

	my $norm2 = 0;
	map { $norm2 += ( $vector2->get( $_ ) || 0 ) ** 2; } keys(%all_tokens);

	my $norm = sqrt( $norm1 * $norm2 );

	if ( $norm ) {
	    $cosine = $dot_product / $norm;
	}

    }

    return $cosine;

}

sub jaccard {

    my $vector1 = shift;
    my $vector2 = shift;

    my $vector_union = $vector1->add( $vector2 , 1 );
    
    my $all_count = 0;
    my $match_count = 0;
    foreach my $token (keys(%{ $vector_union->coordinates })) {
	$match_count += min( $vector1->coordinates->{ $token } || 0 , $vector2->coordinates->{ $token } || 0 );
	$all_count += $vector_union->coordinates->{ $token };
    }

    if ( $all_count ) {
	return ($match_count / $all_count);
    }

    # if we're dealing with 2 null vectors
    return 1;

}

# TODO: create sub-class instead (e.g. VectorBinary) ?
sub binary {

    my $this = shift;

    map { $this->coordinates->{ $_ } = 1; } grep { $this->coordinates->{ $_ } > 0 } keys( %{ $this->coordinates } );

    return $this;

}

# TODO : should this become a field ?
sub dimensionality {
    my $this = shift;
    return scalar( keys( %{ $this->coordinates } ) );
}

#sub TO_JSON {
#    
#    my $this = shift;
#
#    return encode_json( $this->coordinates() );
#    #return $this->_json->encode( $this );
#
#}

#sub FROM_JSON {
#
#    my $this = shift;
#    
#    return new Vector( coordinates => decode_json( shift @_ ) );
#
#}

__PACKAGE__->meta->make_immutable;

1;
