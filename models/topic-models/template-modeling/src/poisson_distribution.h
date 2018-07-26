#ifndef __POISSON_DISTRIBUTION_H__
#define __POISSON_DISTRIBUTION_H__

#include "distribution.h"
#include "probabilistic_object.h"

class PoissonDistribution: public Distribution< unsigned int > {
 
 public:

  /* constructor */
  PoissonDistribution( const Corpus& corpus, double lambda );

  /* get log probability of event */
  double log_probability( const unsigned int & n );

  /* TODO : not sure this belongs here */
  /* compute probability of (joint) unigram appearances in gappy pattern */
  double compute_unigram_probability( const vector< long >& unigrams );

 protected:
  
  /* lambda parameter for a Poisson distribution */
  double _lambda;
  
  /* precomputed Poisson distribution for the gappy pattern lengths */
  static vector<double> _poisson_distribution;

};

/* TODO : there is a confusion between whether an instance of this class represents a distribution or a specific outcome of this distribution */
/* A PoissonProbabilisticObject is an object whose state is obtained through sampling and for which the distribution controlling this sampling is a PoissonDistribution */
template< class T> class PoissonProbabilisticObject: public ProbabilisticObject {

 protected:
  const PoissonDistribution _poisson_distribution;
  
 public:
  
  /* constructor */
  PoissonProbabilisticObject( Corpus& corpus , double lambda )
    :_poisson_distribution(lambda) {

    /* nothing */
    
  }

  double log_probability( const T& event ) {
    /* TODO : is the poisson distribution on the number of words ? */
    return _poisson_distribution.log_probability( event.number_of_words() );
  }
  
};

#endif
