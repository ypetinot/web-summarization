package DMOZ::Mapper::Distribution::UniformDistribution;

use strict;
use warnings;

use ContentDistribution;
use Distribution;
use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use Vocabulary;

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_hierarchy} = $hierarchy;
    # $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

}


# pre-processing method
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    my $word_assignment = $node->get('word-assignment');

    # TODO:
    # for now we don't care about creating distributions at the leaves
    # this will probably have to go in the near future
    if ( $node->type() ne 'category' ) {
	return undef;
    }

    my $token_distribution = undef;

    # compute number of tokens assigned to this node
    my $token_count = scalar( keys(%{ $word_assignment }) );
    
    # if no token is assigned to this node, we simply produce and empty distribution
    if ( !$token_count ) {
	$token_distribution = new Distribution();
    }
    else {

	# compute probability mass that gets assigned to every token
	my $probability_mass = 1 / $token_count;

	# instantiate uniform distribution
	$token_distribution = new Distribution();
	foreach my $token ( keys(%{ $word_assignment }) ) {
	    $token_distribution->probability($token,$probability_mass);
	}

    }

    # store token distribution
    $node->set('distribution-uniform',$token_distribution);

    return undef;

}

# post-processing method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    # nothing

}

# end method
sub end {

    my $this = shift;

    # nothing

}

1;

