#ifndef __PROBABILISTIC_TOKEN_SEQUENCE__
#define __PROBABILISTIC_TOKEN_SEQUENCE__

#include "TokenSequence.hh"

class ProbabilisticTokenSequence: public TokenSequence {

private:
  
  /* probability of this token sequence */
  float _probability;

public:
  
  /* constructor */
  ProbabilisticTokenSequence(vector<unsigned int> tokens, float probability);
  
  /* return the probability of this token sequence */
  double getProbability();

};

#endif
