#ifndef __GAPPY_PATTERN_UNIFORM_DISTRIBUTION_H__
#define __GAPPY_PATTERN_UNIFORM_DISTRIBUTION_H__

#include "multinomial_distribution.h"
#include "corpus.h"
#include "gappy_pattern.h"
#include "poisson_distribution.h"
#include "language_model.h"

/* TODO : is there any commonality with TemplateUniformDistribution ? If so introduce an intermediate class ? */
/* Note : ultimitely this distribution is a distribution over strings (i.e. stringified DappyPattern instances) */
class GappyPatternUniformDistribution: public MultinomialDistribution<GappyPattern> {

 public:

  /* constructor */
 GappyPatternUniformDistribution(const UnigramLanguageModel& ulm, double lambda_number_of_words_in_pattern)
   :_unigram_model(ulm),
    distribution_number_of_words_in_pattern(lambda_number_of_words_in_pattern)  {
    /* nothing */
  }
  
  // Note : a GappyPattern instance corresponds to a component pattern defined by a single color within the full coloring associated with the underlying string => since this GappyPattern instance does have access to the underlying string itself, we can compute the probability of the pattern given the underlying string
  
  /* compute the probability of the specified instance */
  double log_probability( const GappyPattern& instance );

  /* compute probability of (joint) unigram appearances in gappy pattern */
  double compute_unigram_probability( const vector< long >& unigrams );
  
 protected:

  /* unigram model */
  const UnigramLanguageModel _unigram_model;
  
  /* distribution - number of words in pattern */
  // TODO : this should really be a const reference (but not necessarily a const object ?)
  PoissonDistribution distribution_number_of_words_in_pattern;
  
  /* get number of arrangements */
  long get_number_of_arrangements( const GappyPattern& ) const;

  double _base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements );
  
};

#endif
