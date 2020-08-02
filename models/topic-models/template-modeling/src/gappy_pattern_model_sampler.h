#ifndef __GAPPY_PATTERN_MODEL_SAMPLER__
#define __GAPPY_PATTERN_MODEL_SAMPLER__

#include "corpus.h"
#include "gist.h"

class GappyPatternModelSampler {

  /* maximum number of iterations */
  const long _max_iterations;

 public:
  
 GappyPatternModelSampler(int32 max_iterations)
   :_max_iterations(max_iterations)
  {
    /* Nothing for now */
  }
  
  void train(GappyPatternModel model) {
    /* TODO */
    assert(0);
  }
  
};

#endif
