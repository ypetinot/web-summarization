#include "template_uniform_distribution.h"

/* compute the log probability of the specified instance */
double TemplateUniformDistribution::probability( const Template& instance ) {

  /* TODO : should the consistence of the template be checked by the Template class itself ? */
  if ( ! instance.check_consistency() ) {
    return 0;
  }

  /* 1 - poisson distribution ( on the number of slots in this template ) */
  double probability = get_poisson_log_probability( instance._slots.size() );
  
  /* 2 - unigram distribution */
  vector< long > unigrams;
  for ( vector< short int >::const_iterator iter = instance._templatic_status.begin(); iter != _templatic_status.end(); ++iter ) {
    if ( *iter == TEMPLATIC_STATUS_TEMPLATIC ) {
      unigrams.push_back( _gist->get_word( iter - instance._templatic_status.begin() ) );
    }
  }
  probability += log( compute_unigram_probability( unigrams ) );
  
  /* 3 - gap/word arrangement distribution */
  //probability += log( _compute_gappy_pattern_arrangement_probability( gappy_pattern ) );

  return probability;
  
}
