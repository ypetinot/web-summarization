#ifndef __GAPPY_PATTERN_UNIFORM_DISTRIBUTION_H__
#define __GAPPY_PATTERN_UNIFORM_DISTRIBUTION_H__

#include "gappy_pattern.h"
#include "poisson_distribution.h"

/* TODO : is there any commonality with TemplateUniformDistribution ? If so introduce an intermediate class ? */

class GappyPatternUniformDistribution: public Distribution< GappyPattern > {

 protected:

  /* get number of arrangements */
  long get_number_of_arrangements( const GappyPattern& ) const;

  double _base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements );
  
 public:

  // Note : a GappyPattern instance corresponds to a component pattern defined by a single color within the full coloring associated with the underlying string => since this GappyPattern instance does have access to the underlying string itself, we can compute the probability of the pattern given the underlying string
  
  /* compute the probability of the specified instance */
  double log_probability( const GappyPattern& instance );
  
};

#endif
