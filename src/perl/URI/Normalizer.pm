package URI::Normalizer;

use URI;

sub new {

    my $that = shift;
    my %hash;
    my $ref = \%hash;

    bless $ref, $that;

    return $ref;

}

# based on http://en.wikipedia.org/wiki/URL_normalization
sub normalize {

    my $this = shift;
    my $object = shift;

    if ( !ref($object) || (ref($object) ne 'URI') ) {
	$object = new URI($object);
    }
    
    if ( ! $object ) {
	return undef;
    } 
    
    return $object->canonical;

}

1;
