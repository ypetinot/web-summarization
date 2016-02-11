package TargetAdapter::IlpTargetAdapter::IlpProblem;

use strict;
use warnings;

use LPSolver;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'LPSolver::Problem' );

# TODO : reintroduce later on ?
=pod
method add_variable( $source_id , $variable_indices , :$type , :$score_callback = undef , :$data = undef ) {

    if ( $type eq 'ngram' ) {

	# CURRENT : an n-gram is uniquely identified by the combination of its indices and its source
	# => we do not want to replicate a variable more than once unless the same n-gram appears in multiple sources

	# variable_indices is expected to be the indices of tokens in a source sequence
	my $ngram_order = scalar( @{ $variable_indices } );
	my $ngram_surface = 
	my $ngram_variable_key = $this->get_variable_key( 
	    source => $source_id,
	    data => {
		surface => $ngram_surface ,
		count => $ngram_corpus_count
	    } );
	
	# 1 - we create lower order variables by recursing
	if ( $ngram_order > 1 ) {

	    my @lower_order_variables;

	    # add lower order variables
	    for ( my $i = 0 ; $i < $ngram_order ; $i++ ) {

		my @window = map { $i + $_ } ( 0 .. ( $ngram_order - 1 ) );
		my $lower_order_variable_key = $self->add_variable( \@window , type => $type , source => $source , score_callback => $score_callback );

		# add contraints on lower order variable
		# => if an n-gram is activated , all its lower order variables should be activated as well
		# => we need this in particular (not only) since replacement is handled at the single token level ?
		$self->add_constraint(
		[
		 [ $ngram_variable_key , 1 ],
		 [ $lower_order_variable_key , 1 ]
		] , '=' , 0 );

		# add constraint the lower order variable can only active one higher order variable (at specific positions ?)
		# => I think this is was Kapil is doing
		
		# CURRENT : for every single token in the sentence we have the option to:
		# -> keep -> 1 variable -> probability of relevance if keep token
		# -> drop -> results from all other variables at this position
		# -> replace -> 1 variable -> probability of relevance of replacement token
		
	    }

	}

	[ $original_sentence , $i , $j , $k ] , type => 'ngram' , score_callback => \&relevance_probability );
=cut

__PACKAGE__->meta->make_immutable;

1;

package TargetAdapter::IlpTargetAdapter;

# Note : this is definitely a global problem => means ILP is the best way to make sure I can get reasonable output
# Approach: for each unsupported token and their potential alternatives, compute cost of replacement (=> would the cost function still be trainable in this context ?) + set constraints and decode

use strict;
use warnings;

use TargetAdapter::Extractive::Analyzer;
use TargetAdapter::Extractive::FeatureGenerator;
use Web::Summarizer::GeneratedSentence;

use Algorithm::LibLinear;
use Function::Parameters qw/:strict/;
use List::Util qw/min/;
use Memoize;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::TrainedTargetAdapter' );
with( 'TargetAdapter::RelevanceModel' );

# TODO : is there a better solution => since this is an optimization this seems ok ?
memoize( 'relevance_probability' );

# First step (CIKM) : preserve path provided by reference summary
#                     => section 7 : introduce term adaptation model
#                     => section 8 : introduce appearance model => kernel based
# Second step (EMNLP) : combine neighboring summaries in a fusion-like scenario

sub _adapt {

    my $this = shift;
    # TODO : pass in a more integrated object (i.e. more integrated with the alignment data => Alignment object ?)
    my $original_sentence = shift;
    my $alignment = shift;

    my $original_sentence_object = $original_sentence->object;

    # TODO : include sentence start and end symbols
    my @original_sentence_tokens = grep { ! $_->is_punctuation } @{ $original_sentence->object_sequence };
    my $n_original_sentence_tokens = scalar( @original_sentence_tokens );

    # TODO : we should make this a shared configuration parameter somewhere
    my $appearance_threshold = 2;

    # create new LP problem
    # TODO : look for (I)LP solvers with a programmatic API
    my $objective_key = 'obj';
    my $lp_problem = new TargetAdapter::IlpTargetAdapter::IlpProblem(
	id => join( "::" , 'adaptation' , $original_sentence_object->url , $this->target->url ) ,
	objective_key => $objective_key );

    # for each of the original tokens, determine if it is an extractive location
    my @original_sentence_token_is_supported;
    my @original_sentence_token_is_extractive;
    for ( my $i = 0; $i < $n_original_sentence_tokens; $i++ ) {

	my $original_sentence_token = $original_sentence_tokens[ $i ];
	
	# Note : extractive status is only assigned to tokens in the reference summary
	# TODO : add term prior as a contributing factor to extractive nature
	my ( $is_extractive , $object_support_target , $object_support_reference ) = $this->_token_analysis( $original_sentence_object , $original_sentence_token );

	push @original_sentence_token_is_supported, $object_support_target;
	push @original_sentence_token_is_extractive , $is_extractive;

    }

    # collect extractive alternatives
    my $_extractive_alternatives = $this->extractive_analyzer->analyze( $this->target , $original_sentence->object , $original_sentence->raw_string , threshold => $appearance_threshold , max => 20 );
    my @extractive_alternatives = map { $_->[ 0 ] } @{ $_extractive_alternatives };
    my $n_extractive_alternatives = scalar( @extractive_alternatives );

    my %position2alternative_indicators;

    # 0 - define all variables
    # TODO ? => not sure this is absolutely necessary
        
    # 1 - constraint type 1 : an extractive alternative can appear at most once in the adapted summary
    # TODO : this constraint should be changed to forcing multiple instances of a reference token to be mapped with the same extractive alternative
    # => the goal is to avoid the repeated reuse of a single token
    {
	for ( my $i = 0 ; $i < $n_extractive_alternatives ; $i++ ) {
	    
	    my $extractive_alternative = $extractive_alternatives[ $i ];

	    # one indicator variable foreach extractive alternative and each position in the reference summary
	    my @extractive_alternative_at_summary_positions;
	    for ( my $j = 0 ; $j < $n_original_sentence_tokens ; $j++ ) {

		# we only consider transformations at locations that may be extractive
		# (i.e. non-zero probability of being extractive )
		if ( ! $original_sentence_token_is_extractive[ $i ] ) {
		    next;
		}

		my $extractive_alternative_at_summary_position_key = $this->_variable_key( alternative_index => $i , sentence_index => $j , data => $extractive_alternative );
		$lp_problem->add_constraint( [ [ [ $extractive_alternative_at_summary_position_key , 1 ] ] , '<=' , 1 ]);
		$lp_problem->add_constraint( [ [ [ $extractive_alternative_at_summary_position_key , 1 ] ] , '>=' , 0 ]);

		push @extractive_alternative_at_summary_positions , [ $extractive_alternative_at_summary_position_key , 1 ];
		


		# keep track of extractive alternatives indicator at the current summary position
		if ( ! defined( $position2alternative_indicators{ $j } ) ) {
		    $position2alternative_indicators{ $j } = [];
		}
		push @{ $position2alternative_indicators{ $j } } , $extractive_alternative_at_summary_position_key;

	    }
	    
	    if ( scalar( @extractive_alternative_at_summary_positions ) ) {
		my $constraint_1 = [ \@extractive_alternative_at_summary_positions , '<=' , 1 ];
		$lp_problem->add_constraint( $constraint_1 );
	    }
	    
	}
    }

    # 2 - constraint type 2 : if an extractive alternative is activated, then the original token does not appear (i.e. is deactivated)
    # Note : we only consider token to token replacement, not n-gram to n-gram replacement (this might turn into future work)
    {
	for ( my $i = 0 ; $i < $n_original_sentence_tokens ; $i++ ) {

	    # original filler indicator
	    my $original_filler_at_summary_position_key = $this->_variable_key( sentence_index => $i );
	    $lp_problem->add_constraint( [ [ [ $original_filler_at_summary_position_key , 1 ] ] , '<=' , 1  ] );
	    $lp_problem->add_constraint( [ [ [ $original_filler_at_summary_position_key , 1 ] ] , '>=' , 0  ] );

	    # extractive alternative indicators
	    # CURRENT : is this implemented correctly ?
	    my $extractive_alternatives_at_summary_position = $position2alternative_indicators{ $i };

	    my $constraint_2 = [ [ map { [ $_ , 1 ] } ( $original_filler_at_summary_position_key , @{ $extractive_alternatives_at_summary_position } ) ] , '=' , 1 ];
	    $lp_problem->add_constraint( $constraint_2 );

	}
    }
    
    # 3 - constraint type 3 : language model => only allow n-grams that are observed either in the target or in the neighborhood of the target ?
    # => this is where fusion can happen, by allowing connection between constructs that are more than what appears in a single summary
    # TOOD : are there ILP formulations for the tree transduction problem ? This might be a solution here ...
    # TODO : also use appearance frequency in neighborhood to in objective ?
    
    # CURRENT (reasonable) => fusion-like approach => force n-grams to appear in neighborhood, including target, with the exception of adjusted n-grams (since we cannot assume that target specific terms would ever be observed), overall maximizing the likelihood of appearance of the tokens
    # Problem : we want to force n-grams to appear in the neighborhood (entire corpus ?), including the target (yes)
    # ==> generate variables for all possible n-grams in the original sentence => activations
    # ==> individual tokens/phrases can be mapped
    # ==> probabilistic model of conditional relevance

    # TODO : ultimately move skip-gram generation code to the Sequence class
    #my $original_sentence_ngrams = $original_sentence->get_ngrams( 3 , include_punctuation => 1 , with_sentence_boundaries => 1 );

    # constraint - exactly one word can begin a sentence
    # TODO

# TODO : n-gram constraints - reintrodue later
=pod
    # TODO : implement using recursion ?
    my @original_sentence_ngrams;
    my $ngram_order = 3;
    for (my $i = 0 ; $i < $n_original_sentence_tokens - 2 ; $i++ ) {

	my $original_sentence_token_i = $original_sentence_tokens[ $i ];
	my $original_sentence_token_i_surface = $original_sentence_token_i->surface;
	
	for (my $j = $i+1 ; $j < $n_original_sentence_tokens - 1 ; $j++ ) {

	    my $original_sentence_token_j = $original_sentence_tokens[ $j ];
	    my $original_sentence_token_j_surface = $original_sentence_token_j->surface;

	    for (my $k = $j+1 ; $k < $n_original_sentence_tokens ; $k++ ) {

		my $original_sentence_token_k = $original_sentence_tokens[ $k ];
		my $original_sentence_token_k_surface = $original_sentence_token_k->surface;

		# 1 - determine whether this ngram is supported by the corpus (test all reasonable variations => could the server handle this ?)
		my $ngram_surface = join( " " , $original_sentence_token_i_surface, $original_sentence_token_j_surface, $original_sentence_token_k_surface );
		my $ngram_corpus_count = $this->global_data->global_count( 'summary' , $ngram_order , $ngram_surface );

		# Note : threshold seems necessary to keep clear of noisy n-grams
		if ( $ngram_corpus_count >= 10 ) {

		    # we add activation constraints for this trigram
		    # CURRENT : does this enforce a sequence => yes if we seek to maximize an objective that is based on n-grams
		    $this->logger->debug( "Found supported n-gram ($ngram_surface) : $ngram_corpus_count" );

		    # TODO : modify probabilistic model to handle ngrams (should pretty much be the case already)
		    # TODO : do we score only 3 grams ? or 1,2,3 grams jointly ?

		    # removal is equivalent to non-activation =>
		    # located in [New York City] => located in [ Barcelona ]
		    # without phrase handling, city is likely to be replaced by Barcelona (maybe), but the question is what happens when the bi-gram "in city" is not observed
		    # an alternate option is to identify reference supported n-grams (support > 2 ) and treat them as tokens		    
		    # ngram-constraint : if n-gram ijk appears, n-gram ij and n-gram jk must appear as well
		    $lp_problem->add_variable( [ $original_sentence , $i , $j , $k ] , type => 'ngram' , score_callback => \&relevance_probability );

		}

	    }
		
	}

    }
=cut

    # 4 - constraint type 4 : syntax constraints
    # Note : syntax constraints is how we force the removal of linked tokens (sub-trees) if one the key tokens in that subtree is not activated
    # TODO : need to come up with constraints that are specific to the various type subtrees, conjunctions, etc

    # Objective: maximize coverage/relevance probability  => for actually covered terms, the coverage score is 1, for extractive terms, the coverage score is the probability of the selected replacement, and for abstractive terms, the coverage is the appearance probability of the term
    
    # CURRENT : objective should be linear in terms of the variables (that's an assumption right there)
    # the cost (weight) associated with ea_i_j variables is the cost of alignment/replacement between the two (=> must remove features that look at summary context) 
    # => ultimately we want to train the cost function (term-to-term replacement/transformation ?) so that for a given sentence the overall adaptation is correct, not just at individual locations
    # => assumes factorization at the replacement (later all operations ?) level
    # => if so, the objective is just the cost function, where the weights are the weights of individual features
    # => could later on be balanced out with other costs if needed
    # => all the word pairings, including "self" and "epsilon" should be represented

    # TODO : two fundamental probability distributions that should be estimated
    #        1 => replacement probability
    #        2 => appearance probability
    # The ILP formulation searches for the best configuration within this probabilistic model under linguistic constraints (syntex, lm, dependencies ?)
    # Fusion is a possibility by bringing in all the terms that appear in the neighborhood. The joint appearance of these terms is constrained by the linguistic constraints.
    my @objective;
    for ( my $j = 0 ; $j < $n_original_sentence_tokens ; $j++ ) {

    	my $original_sentence_token = $original_sentence_tokens[ $j ];
	my $original_sentence_token_supported = $original_sentence_token_is_supported[ $j ];

	#my $original_sentence_token_extractive = $original_sentence_token_is_extractive[ $j ];
	my $original_sentence_token_extractive = $this->extractive_probability( $original_sentence_token );

	# TODO : could be cleaner => i could/should register the data associated with this variable earlier
	my $original_appearance_at_summary_position = $this->_variable_key( sentence_index => $j , data => $original_sentence_token );

	my $original_sentence_token_relevance_probability = $this->relevance_probability( $original_sentence , $original_sentence_token );

	push @objective , [ $original_appearance_at_summary_position , $original_sentence_token_relevance_probability ];

	# 2 - coverage probability for extractive replacements
	# TODO : abstract out %position2alternative using _variable_key
	my $extractive_alternative_appearances_at_position_j = $position2alternative_indicators{ $j };
	foreach my $extractive_alternative_appearance_at_position_j (@{ $extractive_alternative_appearances_at_position_j }) {
	    
	    my $extractive_alternative_token = $this->_variables_data->{ $extractive_alternative_appearance_at_position_j };
	    my $extractive_alternative_token_supported = 0; # by definition

	    my $extractive_alternative_token_relevance_probability = $this->relevance_probability ( $original_sentence , $original_sentence_token , $extractive_alternative_token );
	    # Note : is it a probability if we sum probabilities ? => logp i believe => ok
	    push @objective , [ $extractive_alternative_appearance_at_position_j , $extractive_alternative_token_relevance_probability ];
	    
	}

	# 3 - coverage of abstractive terms
	# TODO : initially as prior based on neighborhood, then as a more complex model using abstract features for the term
	
    }

    # set objective
    $lp_problem->objective( \@objective );

    # solve ILP
    my ( $solution , $objective_value ) = $this->solve( $lp_problem );

    # generate adapted sentence from solution
    # CURRENT : each appearance variable specifies a specific position => is this acceptable if I am to use a language model later on ?
    # TODO => we need to assign replacements to string values, not to positions => this should make it possible to use the replacements in n-gram LMs
    my @tokens_appearing = map {
	$this->_variables_data->{ $_ }->surface;
    }
    # TODO : what if we stored the expected position in the data associated with this variable ?
    sort { $this->_variable_to_position->{ $a } <=> $this->_variable_to_position->{ $b } }
    # Note : we only look at variables that are activated
    grep { $solution->{ $_ } } keys( %{ $solution } );

# TODO : would this be better ?
=pod
    my $n_tokens_appearing = scalar( @tokens_appearing );
    my $objective_value_normalized = $n_tokens_appearing ? $objective_value / $n_tokens_appearing : $n_tokens_appearing;
=cut

    my $n_tokens_original = $original_sentence->length;
    my $objective_value_normalized = $n_tokens_original ? $objective_value / $n_tokens_original : $n_tokens_original;

    my $adapted_sentence_raw_string = join( " " , @tokens_appearing );
    return Web::Summarizer::GeneratedSentence->new( raw_string => $adapted_sentence_raw_string , object => $this->target , source_id => __PACKAGE__ , score => $objective_value_normalized );

}

# variables data - indexed by variable keys
has '_variables_data' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# variable to position
has '_variable_to_position' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

method _variable_key ( :$alternative_index = undef , :$sentence_index = undef , :$data = undef ) {
    
    my @components;

    if ( defined( $alternative_index ) && defined( $sentence_index ) ) {
	@components = ( 'ea' , $sentence_index , $alternative_index );
    }
    elsif ( defined( $sentence_index ) ) {
	@components = ( 'of' , $sentence_index );
    }
    else {
	die "Request is unsupported ...";
    }

    my $variable_key = join( '_' , @components );

    if ( defined( $data ) ) {
	$self->_variables_data->{ $variable_key } = $data;
    }

    # TODO : this is a bit wasteful, can we do better ?
    if ( defined( $sentence_index ) ) {
	$self->_variable_to_position->{ $variable_key } = $sentence_index;
    }
    
    return $variable_key;

}

with( 'LPSolver' );

__PACKAGE__->meta->make_immutable;

1;
