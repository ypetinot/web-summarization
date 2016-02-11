#include "ProbabilisticTokenSequence.hh"

/* constructor */
ProbabilisticTokenSequence::ProbabilisticTokenSequence(vector<unsigned int> tokens, float probability)
  :TokenSequence(tokens),_probability(probability)
{
  /* nothing for now */
}

/* return the probability of this token sequence */
double ProbabilisticTokenSequence::getProbability() {
  return _probability;
}
