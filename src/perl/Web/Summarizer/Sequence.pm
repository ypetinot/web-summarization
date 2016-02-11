package Web::Summarizer::Sequence;

use strict;
use warnings;

use Featurizable;

use Clone qw/clone/;
use Function::Parameters qw/:strict/;
use Memoize;

# TODO : turn this into a role parameterized on the object type ?
use Moose;
use MooseX::Aliases;
# TODO : use namespace::sweep instead
# http://blogs.perl.org/users/mike_friedman/2011/10/announcing-namespacesweep.html
use namespace::autoclean;

with( 'Featurizable' );
with( 'Logger' );

use overload
    '@{}'  => sub { my $a = shift; return $a->object_sequence; },
    '=='   => sub { return ( $_[ 0 ]->hash_key eq $_[ 1 ]->hash_key ) || 0 ; },
    "bool" => sub { my $a = shift; return $a->length > 0 }; # is this reasonable ?

# weight
has 'weight' => ( is => 'ro' , isa => 'Num' , default => 1 );

# target object
# TODO: any interest in adding more information about the origin of this sentence ?
has 'object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );
has 'source_id' => ( is => 'ro' , isa => 'Str' , required => 1 );

# object sequence
# TODO : parameterize type of array elements ?
# TODO : rename as simply 'sequence'
has 'object_sequence' => ( is => 'ro' , isa => 'ArrayRef' , lazy => 1 , builder => '_object_sequence_builder' );

# hash key
has 'hash_key' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_hash_key_builder' );

# object hash
has '_object_hash' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_object_hash_builder' );
sub _object_hash_builder {
    my $this = shift;
    my %object_hash;
    map { $object_hash{ $_->id }++; } @{ $this->object_sequence };
    return \%object_hash;
}

# return sequence length
sub length {
    my $this = shift;
    return scalar( @{ $this->object_sequence } );
}

# return object at specified index
# TODO: what's the Moose way to implement this ?
sub get_element {
    my $this = shift;
    my $index = shift;
    return $this->object_sequence->[ $index ];
}

# TODO : weight_callback => is this the best way of achieving this ?
# Note : surface_only => necessary, especially for analysis purposes, since some sequences/sentences may be generated without POS information/knowledge
#        TODO : get rid of POS in ngram keys ?
method get_ngrams( $ngram_orders , :$return_vector = 0 , :$weight_callback = undef , :$surface_only = 0 , :$include_punctuation = 0 , :$with_sequence_boundaries = 0 , :$normalize = 0 , :$skip = 0 ) {

    my @ngrams;
    my %_vector_ngrams;	
    my %_key_2_surface;

    my @sequence = grep { $include_punctuation || ! $_->is_punctuation } @{ $self->object_sequence };
    if ( $with_sequence_boundaries ) {
	# TODO ... => need to prepend and append special tokens for this purpose
    }

    if ( ! ref( $ngram_orders ) ) {
	$ngram_orders = [ $ngram_orders ];
    }
    
    foreach my $ngram_order ( @{ $ngram_orders }  ) {

	my @buffer;
	my $buffer_size = 0;
	for (my $i=0; $i<=$#sequence; $i++) {
	    
	    my $current_object = $sequence[ $i ];
	    
	    push @buffer, $current_object;
	    $buffer_size++;
	    
	    if ( $buffer_size > $ngram_order ) {
		shift @buffer;
		$buffer_size--;
	    }
	    
	    my @buffer_copy = @buffer;
	    push @ngrams, \@buffer_copy;

	}
    
	# TODO : how can we avoid duplicating code
	if ( $#buffer > 0 ) {
	    shift @buffer;
	    push @ngrams, \@buffer;
	}

	if ( $return_vector ) {

	    map {
		
		my $ngram_verbalized = $self->_ngram_to_surface( $_ , $normalize );
		my $normalized_ngram = $self->_ngram_to_normalized_key( $_ );
		
		my $ngram_key = $surface_only ? $ngram_verbalized : join( "-" , $ngram_order , $normalized_ngram );
		
		if ( ! $_vector_ngrams{ $ngram_key }++ ) {
		    $_key_2_surface{ $ngram_key } = $ngram_verbalized;
		}
		
	    } @ngrams;
	    
	    if ( $weight_callback ) {
		map { $_vector_ngrams{ $_ } *= $weight_callback->( $self , $ngram_order , $_key_2_surface{ $_ } ); } grep { $_vector_ngrams{ $_ } } keys( %_vector_ngrams );
	    }

	}
	    
    }

    if ( $return_vector ) {
	return new Vector( coordinates => \%_vector_ngrams );
    }

    return \@ngrams;

}

# TODO : clear cache in case the sequence is modified in any way ?
memoize( 'vectorize' );
sub vectorize {

    my $this = shift;
    
    my $vector = $this->get_ngrams( 1 , return_vector => 1 , surface_only => 1 );
    return $vector->scale( $this->weight );

}

sub _ngram_to_normalized_key {

    my $this = shift;
    my $ngram = shift;

    return lc( join( " " , map { $_->key; } @{ $ngram } ) );

}

sub _ngram_to_surface {

    my $this = shift;
    my $ngram = shift;
    my $normalize = shift || 0;

    return lc( join( " " , map { $normalize ? $_->surface_normalized : $_->surface ; } @{ $ngram } ) );

}

sub contains {

    my $this = shift;
    my $object = shift;

    return $this->_object_hash->{ $object->id } || 0;

}

sub filter {
    
    my $this = shift;
    my $filter = shift;
    
    my @filtered_sequence = grep { $filter->( $_ ); } @{ $this->object_sequence };

    # TODO : call constructor using $this so that we create a new Sequence object of the same most derived type as the original sequence
    return __PACKAGE__->new( object => $this->object , object_sequence => \@filtered_sequence , source_id => join( "." , $this->source_id , 'filtered' ) );

}

# TODO : to be removed
=pod
sub BUILDARGS {

    my $that = shift;

    my %args = @_;

    # create a (more-or-less deep) copy of object sequence
    # Note : since that field might get overloaded, we apply this transformation to all ArrayRef-like fields
    foreach my $arg_key (keys( %args )) {
	my $arg_value = $args{ $arg_key };
	if ( ref( $arg_value ) eq 'ARRAY' ) {
#	    my @_copy = @{ $arg_value };
#	    $args{ $arg_key } = \@_copy;
	    my $_copy = clone( $arg_value );
	    $args{ $arg_key } = $_copy;
	}
    }

    return \%args;

}
=cut

__PACKAGE__->meta->make_immutable;

1;
