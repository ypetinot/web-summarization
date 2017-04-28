#include "gappy_pattern_uniform_distribution.h"

/* compute the the probability of the specified instance */
double GappyPatternUniformDistribution::probability( const GappyPattern& instance ) {

  vector<long> unigrams = instance.get_words();
  unsigned int number_of_arrangements = get_number_of_arrangements( instance );

  double log_probability = _base_log_probability( instance.get_number_of_words() , unigrams , number_of_arrangements );
  
  /* the log probability cannot be 0 ? */
  CHECK( log_probability );

  return log_probability;

}

double GappyPatternUniformDistribution::_base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements ) {

  /* 1 - poisson distribution */
  double base_probability = get_poisson_log_probability( number_of_words );

  /* 2 - unigram distribution */
  base_probability += log( compute_unigram_probability( unigrams ) );

  /* 3 - gap/word arrangement distribution */
  //base_probability += log( _compute_gappy_pattern_arrangement_probability( gappy_pattern ) );

  return base_probability;

}

/* get number of arrangements */
long GappyPatternUniformDistribution::get_number_of_arrangements( const GappyPattern& instance ) const {

  /* TODO */
  return 1;

}
