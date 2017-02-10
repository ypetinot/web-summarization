#ifndef __GAPPY_PATTERN_BASE_DISTRIBUTION__
#define __GAPPY_PATTERN_BASE_DISTRIBUTION__

/* TODO: move the base class definition to a different include file ? */
#include "dirichlet_process.h"
#include "poisson_distribution.h"

class GappyPattern;

class GappyPatternBaseDistribution: public PoissonDistribution {

 public:
  
  /* Constructor */
  GappyPatternBaseDistribution( const Corpus& corpus, double lambda );

  /* compute the probability of a specific event */
  virtual double log_probability( const StringifiableObject& event );

 protected:

  /* compute base probability for a (gappy) pattern */
  double _base_log_probability( const GappyPattern* gappy_pattern );
  
#if 0
  /* compute base probability for a single word (new color configuration) */
  double _base_log_probability( long word );
#endif
  
  /* compute base probability */
  double _base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements );

  /* compute probability of (joint) unigram appearances in gappy pattern */
  double _compute_gappy_pattern_unigram_probability( const vector<long>& unigrams ) const;
  
};

#endif
