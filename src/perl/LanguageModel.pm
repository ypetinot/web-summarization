package LanguageModel;

# base class for all language models

use strict;
use warnings;

use Data::Serializer;

my $OOV_TOKEN = "<unk>";

my $serializer = Data::Serializer->new(
    serializer => 'Storable',
#    serializer => 'JSON',
#    serializer => 'Data::Dumper',
#    compress   => 1,
    );

# constructor
sub new {

    my $that = shift;
    
    my $class = ref($that) || $that;

    # obj ref
    my $ref = {};

    bless $ref, $class;

    return $ref;

}

# return the probability of a sequence of tokens
sub probability {

    my $this = shift;
    my $tokens = shift;

    return 0;

}

# return the perplexity of a sequence of tokens
sub perplexity {

    my $this = shift;
    my $tokens = shift;

    return 0;

}

# replaces OOV tokens by a specific symbol
sub normalize_oov_tokens {

    my $this = shift;
    my $tokens = shift;

    my @normalized_tokens = map { $_ || $OOV_TOKEN } @$tokens;

    return \@normalized_tokens;

}

# serialize this object
sub serialize {

    my $this = shift;
    my $target_file = shift;

    # generate serialized value
    my $serialized_value = $serializer->serialize($this);
    
    # write out to target file
    open DESTINATION_FILE, ">$target_file" or die "Unable to serialize language model to destination file $target_file: $!";
    print DESTINATION_FILE $serialized_value;
    close DESTINATION_FILE;

    return 1;

}

# deserialize an object of this class
sub deserialize {

    my $that = shift;
    my $source_file = shift;

    # read serialized value from source file
    local $/ = undef;
    open SOURCE_FILE, $source_file or die "Unable to deserialize language model from source file $source_file: $!";
    my $lm = $serializer->deserialize(<SOURCE_FILE>);
    close SOURCE_FILE;

    return $lm;
    
}

1;
