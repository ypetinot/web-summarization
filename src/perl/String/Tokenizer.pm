package String::Tokenizer;

use strict;
use warnings;

use Function::Parameters qw(:strict);
use List::MoreUtils qw/uniq/;
use Text::Trim;

# TODO : turn into a role ?
use Moose;
use namespace::autoclean;

# normalize text
sub normalize {

    my $that = shift;
    my $raw_text = shift;
    my $normalize_case = shift || 0;

    if ( ! $raw_text ) {
	return '';
    }

    my $normalized_text = $normalize_case ? lc( $raw_text ) : $raw_text ;

    $normalized_text =~ s/[[:space:]]+/ /sg;
    $normalized_text =~ s/^ //sg;
    $normalized_text =~ s/ $//sg;

    return $normalized_text;

}

# tokenize text
method tokenize( $text , :$abstract_numbers = 0 , :$normalize_case = 0 , :$keep_punctuation = 1 ) {

    my $normalized_text = $self->normalize( $text , $normalize_case );
    my @tokens = @{ $self->_tokenize( $normalized_text , keep_punctuation => $keep_punctuation ) };

    # abstract out numbers to NUM
    if ( $abstract_numbers ) {
	# initially added during the implementation of OCELOT, but this is in fact generic enough
	@tokens = map { $_ =~ s/^\d+/NUM/sg; $_; } @tokens;
    }

    # final filtering
    @tokens = grep { defined($_) && length($_) } @tokens;

    return \@tokens;

}

method _tokenize ( $text , :$keep_punctuation = 0 ) {
    
    my @tokens;

    if ( $keep_punctuation ) {
	my @tokens_with_spaces = split /(\s+|[[:punct:]])/, $text;
	@tokens = grep { $_ !~ m/^\s+$/ } @tokens_with_spaces;
    }
    else {
	@tokens = split /\s+|[[:punct:]]/, $text;
	@tokens = map { $_ =~ s/^[[:punct:]]+//; $_; } @tokens;
	@tokens = map { $_ =~ s/[[:punct:]]+$//; $_; } @tokens;
    }

    @tokens = map { trim($_); } grep { defined($_) && length($_); } @tokens;
    
    return \@tokens;

}

# tokenize text into a vector (i.e. hash)
method vectorize( $text , :$use_binary_counts = 0, :$coordinate_weighter = undef ) {

    my @tokenized_text = @{ $self->tokenize( $text ) };
    my @merged_tokenized_text;

    if ( $use_binary_counts ) {
	@merged_tokenized_text = uniq @tokenized_text;
    }
    else {
	@merged_tokenized_text = @tokenized_text;
    }

    my %vector;
    map { $vector{ $_ }++; } @merged_tokenized_text;

    if ( defined( $coordinate_weighter ) ) {
	map { $vector{ $_ } *= $coordinate_weighter->( $_ ); } keys( %vector );
    }

    return new Vector( coordinates => \%vector );

}

=pod
sub basic_tokenize {

    my $string = shift;

    split /\s+/, $string;
    # TODO : do not filter punctuation by default
    grep { $_ !~ m/^\p{Punct}+$/ }

    my @chunked_string = map { my @components = split /\//, $_; \@components; }

}
=cut

1;
