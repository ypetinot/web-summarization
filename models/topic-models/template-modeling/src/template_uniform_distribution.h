#ifndef __TEMPLATE_UNIFORM_DISTRIBUTION__
#define __TEMPLATE_UNIFORM_DISTRIBUTION__

#include "poisson_distribution.h"

/* TemplateUniformDistribution - defines a uniform distribution over structurally acceptable sentence templates */

/* TODO : this class should probably be defined as a friend class of the Template class */
class TemplateUniformDistribution: PoissonDistribution<Template> {

 public:

  /* compute the log probability of the specified instance */
  double probability( const Template& instance );
  
}

#endif
