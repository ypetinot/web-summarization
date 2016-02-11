package TypeSignature;

use strict;
use warnings;

use Moose::Role;

with( 'Freebase' );

# TODO : wouldn't this belong directly in Freebase instead ?
sub type_signature_freebase {
    
    my $this = shift;
    my $string = shift;

    # CURRENT : how do load a specific version of Freebase ?
    # TODO : we probably have already looked up the entity for the current slot filler, reuse ?
    my $string_entities = $this->map_string_to_entities( $string );

    my %_types;

    # TODO : how can we apply a prior on each entity ?
    # Note : for now we adopt a uniform prior
    foreach my $string_entity (@{ $string_entities }) {
	
	my $string_entity_types = $this->map_entity_to_types( $string_entity );
	map {

	    my $type_key = $_;

	    # we keep track of the full topic key
	    $_types{ $type_key }++;

	    # we also keep track of topic elements
	    # e.g. currently "Saint Peter's College" and "Rutgers" would *not* match on any "education.*" topic
	    my @type_key_elements = split /\./ , $type_key;
	    pop( @type_key_elements );
	    while ( scalar( @type_key_elements ) ) {
		my $type_key_ancestor = join( '.' , @type_key_elements );
		$_types{ $type_key_ancestor }++;
		pop @type_key_elements;
	    }

	}
	grep {
	    # filter common.topic
	    ( $_ ne 'common.topic' ) &&
		( $_ !~ m/^base\./ )
	}
	@{ $string_entity_types };

    }

    return new Vector( coordinates => \%_types );

}

1;
