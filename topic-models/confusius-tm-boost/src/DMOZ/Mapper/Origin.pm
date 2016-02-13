package DMOZ::Mapper::Origin;

use ContentDistribution;
use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use Vocabulary;

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_hierarchy} = $hierarchy;
    $this->{_vocabulary} = $hierarchy->getProperty('vocabulary');

    $this->{_n_docs} = 0;
    $this->{_current_ratios} = {};

}


# pre-processing method
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    my $word_origin = $node->get('word-assignment');

    if ( $node->type() eq 'category' ) {
	return $word_origin;
    }

    # get tokens for this entry
    my @tokens = split(/\s+/,$node->get('description'));

    my %ratios;

    if ( scalar(@tokens) ) {

	# iterate over path, looking for most likely source of every word in this distribution
	foreach my $token (@tokens) {
	    my $token_origin = $this->_get_word_origin($data, $word_origin, $token);
	    if ( !defined($token_origin) ) {
		print STDERR "found OOV token: $token\n";
		$token_origin = 'OOV';
	    }
	    $ratios{$token_origin}++;
	}
    
	# normalize by length
	map { $ratios{$_} /= scalar(@tokens); } keys(%ratios);

	# update global ratio information
	map { $this->{_current_ratios}->{$_} += $ratios{$_}; } keys(%ratios);

	# update global document count
	$this->{_n_docs}++;

    }

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

    # normalize ratios
    map { $this->{_current_ratios}->{$_} /= $this->{_n_docs}; } keys(%{ $this->{_current_ratios} });

    # output ratio information
    map { print join("\t", $_, $this->{_current_ratios}->{$_}) . "\n"; } keys(%{ $this->{_current_ratios} });

    # store ratio information
    $this->{_hierarchy}->setProperty('origin-priors', $this->{_current_ratios});

}

# which node in the current path generated this word ?
sub _get_word_origin {

    my $this = shift;
    my $path_data = shift;
    my $local_data = shift;
    my $word = shift;

    my $depth = scalar(@$path_data);

    my $i;
    for ($i=0; $i<$depth; $i++) {
	if ( $path_data->[$i]->{$word} ) {
	    return $i;
	}
    }

    if ( $local_data->{$word} ) {
	return $depth;
    }

    return undef;

}

1;

