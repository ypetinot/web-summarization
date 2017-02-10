#ifndef __TEMPLATE_BASE_DISTRIBUTION_H__
#define __TEMPLATE_BASE_DISTRIBUTION_H__

#include "distribution.h"
#include "poisson_distribution.h"

class TemplateBaseDistribution: public PoissonDistribution {

 public:
  
  /* constructor */
  TemplateBaseDistribution( const Corpus& corpus , double lambda );

  /* compute the probability of a specific event */
  virtual double log_probability( const StringifiableObject& event );

 protected:

};

#endif
