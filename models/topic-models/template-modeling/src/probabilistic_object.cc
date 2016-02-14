#include "probabilistic_object.h"

dsfmt_t dsfmt;

void init_random(unsigned params_random_seed) {
#ifdef USE_MT_RANDOM
  dsfmt_init_gen_rand(&dsfmt, params_random_seed);
#else
  srand(params_random_seed);
#endif
}

double sample_uniform() {
#ifdef USE_MT_RANDOM
  return dsfmt_genrand_close_open(&dsfmt);
#else
  return random() / (double)RAND_MAX;
#endif

}

/* compute the probability of this object */
double ProbabilisticObject::probability() {

  return exp( this->log_probability() );

}

/* constructor */
PoissonProbabilisticObject::PoissonProbabilisticObject( Corpus& corpus , double lambda )
  :PoissonDistribution(corpus,lambda) {

  /* nothing */

}
