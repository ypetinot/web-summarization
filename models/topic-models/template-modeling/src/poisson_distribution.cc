#include "poisson_distribution.h"

#include "corpus.h"
#include "statistics.h"

#include <glog/logging.h>

/* precomputed Poisson distribution for the gappy pattern lengths */
vector<double> PoissonDistribution::_poisson_distribution;

/* constructor */
PoissonDistribution::PoissonDistribution( const Corpus& corpus, double lambda )
  :Distribution(corpus),_lambda(lambda) {

  /* nothing */

}

double PoissonDistribution::get_poisson_log_probability( unsigned int n_words ) {

  CHECK_GE( n_words , 0 );

  while ( (int) n_words > ( (int) _poisson_distribution.size() - 1 ) ) {
    _poisson_distribution.push_back( logPoisson( _lambda , _poisson_distribution.size() ) );
  }

  CHECK( n_words < _poisson_distribution.size() );

  return _poisson_distribution[ n_words ];
  
}

/* compute probability of (joint) unigram appearances in gappy pattern */
double PoissonDistribution::compute_unigram_probability( const vector< long >& unigrams ) {

  double total_unigram_count = _corpus.get_total_unigram_count();
  CHECK( total_unigram_count > 0 );

  double probability = 1.0;
  
  for ( vector<long>::const_iterator iter = unigrams.begin(); iter != unigrams.end(); iter++ ) {
    
    // TODO : proper smoothing for unigram distribution ? at least implement Laplace smoothing ...
    probability *= ( _corpus.get_unigram_count( *iter ) / total_unigram_count ) + 0.001;
    
  }
  
  return probability;
  
}
