#include "template_dp.h"

/* Constructor */
TemplateDP::TemplateDP( unsigned int max_colors )
  :_max_colors(max_colors)
{

  /* nothing for now */

}

/* sample for a target sequence / index */
void TemplateDP::gibbs_sampler_single( const Gist* sequence , unsigned int index ) {

  /* 1 - remove target word */

  /* 2 - compute transition distribution */

  /* 3 - sample from transition distribution */

  /* 4 - update counts */

}
