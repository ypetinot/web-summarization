package StringVector;

use Moose;

extends 'Vector';

### # tokenization/segmentation method
### has 'tokenization' => ( is => 'ro' , 'isa' => 'CodeRef' , required => 0 );

# TODO: add option to handle HTML content seemlessly ?

sub BUILDARGS {

    my $class = shift;
    my $string = shift;

    my $tokenized_string = _tokenization( $string );

    my %args;
    $args{ 'coordinates' } = $tokenized_string;

    return \%args;

}

# Tokenization
sub _tokenization {

    my $string = shift;

    my %token_frequencies;
    if ( $string ) {
	map { $token_frequencies{ lc( $_ ) }++ ; } split /\s+/, $string;
    }

    return \%token_frequencies;

}


    
no Moose;

1;
