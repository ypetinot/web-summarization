#include "gappy_pattern_uniform_distribution.h"

#include <glog/logging.h>

/* compute the the probability of the specified instance */
double GappyPatternUniformDistribution::log_probability( const GappyPattern& instance ) {

  vector<long> unigrams = instance.get_words();
  unsigned int number_of_arrangements = get_number_of_arrangements( instance );

  double log_probability = _base_log_probability( instance.get_number_of_words() , unigrams , number_of_arrangements );
  
  /* the log probability cannot be 0 ? */
  CHECK( log_probability );

  return log_probability;

}

double GappyPatternUniformDistribution::_base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements ) {

  /* 1 - poisson distribution */
  double base_probability = distribution_number_of_words_in_pattern.log_probability( number_of_words );

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

/* compute probability of (joint) unigram appearances in gappy pattern */
double GappyPatternUniformDistribution::compute_unigram_probability( const vector< long >& unigrams ) {

  double total_unigram_count = _unigram_model.get_total_unigram_count();
  CHECK( total_unigram_count > 0 );

  double probability = 1.0;
  
  for ( vector<long>::const_iterator iter = unigrams.begin(); iter != unigrams.end(); iter++ ) {
    
    // TODO : proper smoothing for unigram distribution ? at least implement Laplace smoothing ...
    probability *= ( _unigram_model.get_unigram_count( *iter ) / total_unigram_count ) + 0.001;
    
  }
  
  return probability;
  
}
