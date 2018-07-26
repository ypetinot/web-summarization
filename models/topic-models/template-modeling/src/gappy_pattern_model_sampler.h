#ifndef __GAPPY_PATTERN_MODEL_SAMPLER__
#define __GAPPY_PATTERN_MODEL_SAMPLER__

class GappyPatternModelSampler {

  /* Corpus instance against which to perform sampling */
  const Corpus& _corpus;
  
  /* maximum number of iterations */
  const long _max_iterations;

 public:
  
 GappyPatternModelSampler(const Corpus& corpus, int32 max_iterations)
   :_corpus(corpus),_max_iterations(max_iterations)
  {
    /* Nothing for now */
  }
  
  void train(GappyPatternModel model) {
    /* TODO */
    assert(0);
  }
  
};

#endif
