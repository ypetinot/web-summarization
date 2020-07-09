#include "gappy_pattern_base_distribution.h"

#include "gappy_pattern.h"

#include <glog/logging.h>

/* Constructor */
GappyPatternBaseDistribution::GappyPatternBaseDistribution( const Corpus& corpus, double lambda )
  :PoissonDistribution(corpus,lambda) {

  /* nothing */

}

/* compute the probability of a specific event */
double GappyPatternBaseDistribution::log_probability( const StringifiableObject& event ) {
  
  return _base_log_probability( &((const GappyPattern&) event) );

}

#if 0
double GappyPatternBaseDistribution::_base_log_probability( long word ) {
  
  vector<long> unigrams;
  unigrams.push_back( word );

  return _base_log_probability( 1 , unigrams , 1 );

}
#endif

double GappyPatternBaseDistribution::_base_log_probability( const GappyPattern* gappy_pattern ) {



}

