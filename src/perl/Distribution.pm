package Distribution;

# Abstracts the notion of a discrete distribution

use strict;
use warnings;

#TODO: there doesn't seem to be any equivalent code in CPAN to manipulate distributions

# constructor
sub new {

    my $that = shift;

    my $class = ref($that) || $that;

    my $ref = {};
    $ref->{_event_2_probability} = {};
    $ref->{_auto_check_consistency} = 0;
    $ref->{_total_mass} = 0;

    bless $ref, $class;

    return $ref;

}

# get/set the probability of a particular event
sub probability {

    my $this = shift;
    my $event_key = shift;
    my $event_probability = shift;

    if ( defined($event_probability) ) {
	my $previous_probability = $this->{_event_2_probability}->{$event_key} || 0;
	$this->{_event_2_probability}->{$event_key} = $event_probability;
	$this->{_total_mass} += $event_probability - $previous_probability;
    }

    # check distribution constistency
    $this->check_consistency();

    return $this->{_event_2_probability}->{$event_key} || 0;

}

# get list of non-zero probability events
sub events {

    my $this = shift;

    my @events = keys( %{ $this->{_event_2_probability} } );

    return \@events;

}

# normalize this distribution
sub normalize {

    my $this = shift;

    # nothing to do if the distribution is already normalized
    if ( $this->{_total_mass} == 1 ) {
	return;
    }

    foreach my $key (keys( %{$this->{_event_2_probability}} )) {
	$this->{_event_2_probability}->{$key} /= $this->{_total_mass};
    }

}

# check the consistency of this distribution
sub check_consistency() {

    my $this = shift;
    
    if ( ! $this->{_auto_check_consistency} ) {
	return 1;
    }

    # TODO
    # send warning / throw exception is something is wrong

    return 1;

}

1;
