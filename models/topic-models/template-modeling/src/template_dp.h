#ifndef __TEMPLATE_DP__
#define __TEMPLATE_DP__

class TemplateDP {

 public:

  /* Constructor */
  TemplateDP( unsigned int max_colors );

  /* sample for a target sequence / index */
  void gibbs_sampler_single( const Gist* gist , unsigned int index );

  /* dump */
  void dump();

 protected:

  /* max number of colors */
  unsigned int _max_colors;

};

#endif
