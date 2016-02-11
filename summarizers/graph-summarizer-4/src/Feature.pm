package Feature;

use strict;
use warnings;

# base for all features

use Moose::Role;
use namespace::autoclean;

with ('Identifiable');

requires 'compute';

sub cache_key {
    return join( "::" , @_ );
}

# cache
has '_value_cache' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# TODO : implement using memoize ?
sub compute_cached {

    my $this = shift;

    # TODO : add proper keys so that the cache key is not made of array addresses
#    my @_mapped_args = map { ref( $_ ) eq 'ARRAY' ? ( @{ $_ } ) : ( $_ ) } @_;
#    my $cache_key = $this->cache_key( @_mapped_args );
#    my $cache_key = $this->cache_key( map { ref( $_ ) eq 'ARRAY' ? ( @{ $_ } ) : ( $_ ) } @_ );
    my $cache_key = $this->cache_key( @_ );

    if ( ! defined( $this->_value_cache->{ $cache_key } ) ) {
	# store in cache
	$this->_value_cache->{ $cache_key } = $this->compute( @_ );
    }
    else {
###	print STDERR "Getting value from cache !\n";
    }

    return $this->_value_cache->{ $cache_key };
	
}

=pod
sub compute {

    my $this = shift;
    my $input_object = shift;
    my $output_object = shift;

    # ...

}
=cut

1;
