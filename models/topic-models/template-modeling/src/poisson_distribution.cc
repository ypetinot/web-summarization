#include "poisson_distribution.h"
#include "statistics.h"

#include <glog/logging.h>

/* precomputed Poisson distribution for the gappy pattern lengths */
vector<double> PoissonDistribution::_poisson_distribution;

/* constructor */
PoissonDistribution::PoissonDistribution( double lambda )
  :Distribution(),_lambda(lambda) {

  /* nothing */

}

double PoissonDistribution::log_probability( const unsigned int & n_words ) {

  CHECK_GE( n_words , 0 );

  while ( (int) n_words > ( (int) _poisson_distribution.size() - 1 ) ) {
    _poisson_distribution.push_back( logPoisson( _lambda , _poisson_distribution.size() ) );
  }

  CHECK( n_words < _poisson_distribution.size() );

  return _poisson_distribution[ n_words ];
  
}
