#include "sampler.h"

double Sampler::sample_uniform() {
#ifdef USE_MT_RANDOM
  return dsfmt_genrand_close_open(&dsfmt);
#else
  return random() / (double)RAND_MAX;
#endif
}

/* TODO : decide whether to rely on dSFMT or GSL for random number generation */
unsigned long int Sampler::sample_integer_uniform(unsigned int from, unsigned int to) {
  assert( to > from );
  unsigned long int normalized_range = to - from;
  return gsl_rng_uniform_int(_gsl_rng,normalized_range);
}

