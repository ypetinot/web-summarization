#ifndef __SAMPLER_H__
#define __SAMPLER_H__

#include <dSFMT.h>
#include <gsl/gsl_randist.h>
#include <gsl/gsl_rng.h>

class Sampler {

  dsfmt_t dsfmt;

  void init_random(unsigned params_random_seed) {
#ifdef USE_MT_RANDOM
  dsfmt_init_gen_rand(&dsfmt, params_random_seed);
#else
  srand(params_random_seed);
#endif
  };

 protected:
  
  /* gsl random number generator */
  gsl_rng* _gsl_rng;

  /* default constructor */
  Sampler(unsigned int random_seed) {
    /* do i still need this ? */
    init_random(random_seed);
    /* init gsl random number generator */
    _gsl_rng = gsl_rng_alloc( gsl_rng_taus );
  };

  double sample_uniform();
  unsigned long int sample_integer_uniform(unsigned int from, unsigned int to);
  
};

#endif
