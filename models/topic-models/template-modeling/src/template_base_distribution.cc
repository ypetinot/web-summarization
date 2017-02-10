#include "template_base_distribution.h"

#include <glog/logging.h>

/* constructor */
TemplateBaseDistribution::TemplateBaseDistribution( const Corpus& corpus , double lambda )
  :PoissonDistribution(corpus,lambda) {

  /* nothing */

}

/* compute the probability of a specific event */
double TemplateBaseDistribution::log_probability( const StringifiableObject& event ) {

  /* TODO */
  CHECK( 0 );

    /* 1 - poisson distribution */
  double base_probability = get_poisson_log_probability( event.get_number_of_words() );

  /* 2 - unigram distribution */
  base_probability += log( _compute_gappy_pattern_unigram_probability( unigrams ) );

  /* 3 - gap/word arrangement distribution */
  //base_probability += log( _compute_gappy_pattern_arrangement_probability( gappy_pattern ) );

  return base_probability;

}
