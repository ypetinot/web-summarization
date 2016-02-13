package UniformLanguageModel;

# Uniform Language Model - splits probability mass uniformly among the specified vocabulary tokens
# and assumes 0 probability for any other token   

use strict;
use warnings;

use LanguageModel;
use base('LanguageModel');

# constructor
sub new {

    my $that = shift;
    my $tokens = shift;

    # obj ref
    my $ref = $that->SUPER::new();

    # vocab
    $ref->{_vocab} = {};
    foreach my $token (@$tokens) {
	$ref->{_vocab}->{$token} = 1;
    }

    # probability mass distribution
    my $token_count = scalar(@$tokens);
    $ref->{_uniform_mass} = 1 / $token_count;

    return $ref;

}

sub probability {

    my $this = shift;
    my $tokens = shift;

    my @_tokens;

    if ( ref($tokens) ) {
	push @_tokens, @$tokens;
    }
    
    my $probability = undef;
    foreach my $token (@_tokens) {
	
	if (!defined($probability)) {
	    $probability = 1;
	}

	$probability *= (defined($this->{_vocab}->{$token}))?$this->{_uniform_mass}:0;

    }

    return $probability;

}

1;
