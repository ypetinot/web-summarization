package DMOZ::BackoffDistribution;

# base class for all Backoff Distributions
# Backoff Distributions are intended to model unassignment vocabulary in a Hierarchical Language Model
# For this purpose the base class 

use strict;
use warnings;

use Distribution;
use Vocabulary;

# constructor
sub new {

    my $that = shift;
    my $vocabulary = shift;

    my $class = ref($that) || $that;

    my $ref = {};
    $ref->{_vocabulary} = $vocabulary;

    bless $ref, $class;
    $ref->reset();

    return $ref;

}

# reset assigned vocabulary
sub reset {
    my $this = shift;
    $this->{_assigned_vocabulary} = {};
    $this->{_distribution} = new Distribution();
}

# set/get symbol to assigned vocabulary
sub assigned {
    my $this = shift;
    my $token = shift;
    my $is_assigned = shift;

    if ( defined($is_assigned) ) {
	if ( $is_assigned ) {
	    $this->{_assigned_vocabulary}->{$token} = 1;
	}
	else {
	    delete($this->{_assigned_vocabulary}->{$token});
	}
    }

    return defined($this->{_assigned_vocabulary}->{$token});
}

# compute distribution based on the tokens that have already been assigned
# to be overridden by sub-classes
sub compute {

    my $this = shift;

    # nothing, this is a default implementation

}

# obtain the probability of a given symbol
# on the tokens that have not been assigned can have a non-zero probability
sub probability {

    my $this = shift;
    my $token = shift;

    # check if this token is assigned
    # if so it isn't covered by this distribution
    if ( $this->assigned($token) ) {
	return 0;
    }

    # default implementation
    return $this->{_distribution}->probability($token);

}

1;

