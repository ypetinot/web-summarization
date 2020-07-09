#ifndef __POISSON_DISTRIBUTION_H__
#define __POISSON_DISTRIBUTION_H__

#include "distribution.h"
#include "probabilistic_object.h"

class PoissonDistribution: public Distribution< unsigned int > {
 
 public:

  /* constructor */
  PoissonDistribution(double lambda);

  /* get log probability of event */
  double log_probability( const unsigned int & n );

 protected:
  
  /* lambda parameter for a Poisson distribution */
  double _lambda;
  
  /* precomputed Poisson distribution for the gappy pattern lengths */
  static vector<double> _poisson_distribution;

};

#endif

#if 0
/* TODO : there is a confusion between whether an instance of this class represents a distribution or a specific outcome of this distribution */
/* A PoissonProbabilisticObject is an object whose state is obtained through sampling and for which the distribution controlling this sampling is a PoissonDistribution */
template< class T> class PoissonProbabilisticObject: public ProbabilisticObject {

 protected:
  const PoissonDistribution _poisson_distribution;
  
 public:
  
  /* constructor */
  PoissonProbabilisticObject(double lambda)
    :_poisson_distribution(lambda) {

    /* nothing */
    
  }

  double log_probability( const T& event ) {
    /* TODO : is the poisson distribution on the number of words ? */
    return _poisson_distribution.log_probability( event.number_of_words() );
  }
  
};

#endif
