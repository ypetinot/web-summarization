package DMOZ::Mapper::Distribution::RenormalizedDistribution;

use strict;
use warnings;

use VectorContentDistribution;
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
    my $content_distribution = $node->get('content-distribution');

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

	# compute normalization probability mass
	my $normalization_probability_mass = 0;
	foreach my $token ( keys(%{ $word_assignment }) ) {
	    $normalization_probability_mass += $content_distribution->probability($token);
	}

	# instantiate renormalized distribution
	$token_distribution = new Distribution();
	foreach my $token ( keys(%{ $word_assignment }) ) {
	    my $raw_probability = $content_distribution->probability($token);
	    my $normalized_probability = $raw_probability / $normalization_probability_mass;
	    $token_distribution->probability($token,$normalized_probability);
	}

    }

    # store token distribution
    $node->set('distribution-renormalized',$token_distribution);

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

