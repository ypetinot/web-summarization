#ifndef __POISSON_DISTRIBUTION_H__
#define __POISSON_DISTRIBUTION_H__

#include "distribution.h"
#include "probabilistic_object.h"

template< class T> class PoissonDistribution: public Distribution {
 
 public:

  /* constructor */
  PoissonDistribution( const Corpus& corpus, double lambda );

  /* get log probability */
  double get_poisson_log_probability( unsigned int n );

  /* TODO : not sure this belongs here */
  /* compute probability of (joint) unigram appearances in gappy pattern */
  double compute_unigram_probability( const vector< long >& unigrams );

 protected:
  
  /* lambda parameter for a Poisson distribution */
  double _lambda;
  
  /* precomputed Poisson distribution for the gappy pattern lengths */
  static vector<double> _poisson_distribution;

};

template< class T> class PoissonProbabilisticObject: public ProbabilisticObject, public PoissonDistribution<T> {

 public:

  /* constructor */
  PoissonProbabilisticObject( Corpus& corpus , double lambda )
    :PoissonDistribution<T>(corpus,lambda) {

    /* nothing */
    
  }
  
};

#endif
