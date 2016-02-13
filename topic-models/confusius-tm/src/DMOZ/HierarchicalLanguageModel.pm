package DMOZ::HierarchicalLanguageModel;

use strict;
use warnings;

# abstracts a HierarchicalLanguageModel over the DMOZ Hierarchy

use LanguageModel;
use base('LanguageModel');

use Tokenizer;
use Vocabulary;
use VectorContentDistribution;

use Data::Dumper;

$| = 1;

# contructor
sub new {

    my $that = shift;
    my $hierarchy = shift;
    my $distribution_mode = shift;
    my $distribution_backoff = shift; 

    # construct super class
    my $ref = $that->SUPER::new();
    $ref->{_hierarchy} = $hierarchy;
    $ref->{_vocabulary} = $hierarchy->getProperty('vocabulary');
    $ref->{_origin_priors} = $hierarchy->getProperty('origin-priors');
   
    # the set of distributions we use
    $ref->{_distribution_mode} = $distribution_mode;

    # the plug-in/replacement distribution we use for the document-specific nodes
    eval("use $distribution_backoff;");
    if ( $@ ) {
	die "Unable to load distribution backoff module $distribution_backoff ...";
    }
    my $distribution_backoff_object = $distribution_backoff->new( $ref->{_vocabulary} );
    if ( !$distribution_backoff_object ) {
	die "Unable to instantiate distribution backoff module for class $distribution_backoff ...";
    } 
    $ref->{_backoff_lm} = $distribution_backoff_object;
    $ref->{_backoff_cache} = {};

    return $ref;

}

# compute perplexity of a given sequence of tokens
sub perplexity {

    my $this = shift;
    my $tokens = shift;
    my $target_path_data = shift;

    my $total_log_probability = $this->probability($tokens,$target_path_data);

    my $normalized_entropy = 0;
    my $total_perplexity = 0;
   
    if ( scalar(@$tokens) && $total_log_probability ) {
	$normalized_entropy = ( -1 * $total_log_probability / scalar(@$tokens) ) / log(exp(1));
	$total_perplexity = exp($normalized_entropy);
    }
    
    return $total_perplexity;

}

# compute probability of a given sequence of tokens
sub probability {

    my $this = shift;
    my $tokens = shift;
    my $target_path_data = shift;

    my $total_log_probability = 0;
    my $n_oovs = 0;
    my $n_zero_prob = 0;

    my @normalized_tokens = @$tokens;
    my @tokens_with_origin;

    my $current_depth = scalar(@$target_path_data);

    # configure backoff model
    # TODO: could be optimized to only consider the target string's tokens ?
    $this->configure_backoff($target_path_data, $current_depth);

    # process each token individually
    foreach my $token (@normalized_tokens) {

	my $token_probability = 0;
	my $is_generated_by_hierarchy = 0;

	my $most_likely_origin = undef;
	my $most_likely_origin_probability = 0;
	my $most_likely_origin_conditional_probability = 0;

	my $priors_weight = 0;

	foreach my $origin (keys(%{ $this->{_origin_priors} })) {

	    my $origin_prior = $this->{_origin_priors}->{$origin};

            # the category priors are in effect up to the target depth
	    if ( $origin ne 'OOV' && $origin < $current_depth ) {
		
		$priors_weight += $origin_prior;

		if ( $target_path_data->[$origin]->[0]->{$token} ) {
		    
		    my $local_language_model = $target_path_data->[$origin]->[2];

		    my $local_conditional_probability = $local_language_model->probability($token);
		    my $local_token_probability = $origin_prior * $local_conditional_probability;
		
		    if ( !$local_token_probability ) {
			print STDOUT "problem: $token [" . $this->{_vocabulary}->get_word($token) . "] has probability 0 while assigned at level [" . $origin . "/" . scalar(@$target_path_data) . "]\n";
		    }
		    elsif ( $local_token_probability + 0 != $local_token_probability ) {
			print STDERR "problem: $token [" . $this->{_vocabulary}->get_word($token) . "] has probability $token_probability at level [" . $origin . "/" . scalar(@$target_path_data) . "]\n";
		    }

		    # print STDERR "local probability for token $token is $local_token_probability at level $origin ...\n";

		    # update origin information
		    if ( $local_token_probability > $most_likely_origin_probability ) {
			# print STDERR "updating most likely origin for token $token: $origin\n";
			$most_likely_origin = $origin;
			$most_likely_origin_probability = $token_probability;
			$most_likely_origin_conditional_probability = $local_conditional_probability;
		    }

		    $token_probability += $local_token_probability;
		    $is_generated_by_hierarchy++;

		}
		
	    }

	}

	# backoff model for the leaf - document-specific - node
	# model OOV contributions and, possibly, the rest of the vocabulary
	{
	    
	    # we check the cache first, obtaining token probabilities might be expensive
	    my $backoff_conditional_probability = $this->{_backoff_cache}->{$token};

	    if ( ! $backoff_conditional_probability ) {
		$backoff_conditional_probability = $this->{_backoff_lm}->probability($token);
		$this->{_backoff_cache}->{$token} = $backoff_conditional_probability;
	    }
	    
	    if ( !$token_probability && !$backoff_conditional_probability ) { 
		print STDERR "problem: $token has no backoff probability\n";
	    }
	    elsif ( $backoff_conditional_probability ) {
		$token_probability += (1 - $priors_weight) * $backoff_conditional_probability;
	    }
	    
	    # true OOV ?
	    # TODO: can we do better ?
	    if ( $backoff_conditional_probability > $most_likely_origin_conditional_probability ) {
		$most_likely_origin = 'oov';
		$most_likely_origin_conditional_probability = $backoff_conditional_probability;
		$n_oovs++;
	    }
	    
	}

	if ( !defined($most_likely_origin) ) {
	    die "[HierarchicalLanguageModel] undefined origin for token [$token] ...";
	}

	push @tokens_with_origin, "[${token}:${most_likely_origin}:${most_likely_origin_conditional_probability}]";

	if ( $is_generated_by_hierarchy > 1 ) {
	    print STDERR "problem: $token is assigned to more than one level\n";
	    print STDERR "\t" . join(" ", map{ $_->[2]; } @$target_path_data) . "\n";
	}

	if ( $token_probability ) {
	    $total_log_probability += log($token_probability);
	}
	else {
	    print STDERR "problem: $token has probability 0\n";
	    $n_zero_prob++;
	}

    }
    
    return { 'probability' => $total_log_probability, 'tokens' => join(' ', @normalized_tokens), 'origins' => join(' ', @tokens_with_origin), 'token_count' => scalar(@normalized_tokens), 'oov_count' => $n_oovs, 'zero_probability_count' => $n_zero_prob };

}

# build backoff lm
sub configure_backoff {

    my $this = shift;
    my $target_path_data = shift;
    my $current_depth = shift;
    
    # first reset the backoff lm
    $this->{_backoff_lm}->reset();

    # process vocabulary
    my @vocabulary_words = @{ $this->{_vocabulary}->word_indices() };
    foreach my $vocabulary_word (@vocabulary_words) {

	foreach (my $origin=0; $origin<scalar(@{$target_path_data}); $origin++) {
	
	    if ( $origin < $current_depth ) {
		if ( $target_path_data->[$origin]->[0]->{$vocabulary_word} ) {
		    $this->{_backoff_lm}->assigned($vocabulary_word,1);
		    last;
		}
	    }
	    else {
		last;
	    }

	}

    }

    # finalize lm
    $this->{_backoff_lm}->compute();

}

# destructor
sub DESTROY {

    my $this = shift;

    # nothing

}

1;

