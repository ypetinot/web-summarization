#ifndef __PROBABILISTIC_OBJECT_H__
#define __PROBABILISTIC_OBJECT_H__

#include "definitions.h"
#include "statistics.h"
#include "sampler.h"
#include "stringifiable.h"
#include <vector>

void init_random(unsigned params_random_seed);
double sample_uniform();

using namespace std;

class MultinomialSampler: public Sampler {
  
 public:
  
  /* multinomial sampling */
  template<class T> unsigned int multinomial_sampler( vector<T> objects , vector<double> probabilities ) const {
    
    unsigned int multinomial_size = objects.size();
    
    vector<unsigned int> multinomial_sample( multinomial_size , 0 );
    gsl_ran_multinomial( _gsl_rng , multinomial_size , 1 , &probabilities[0] , &multinomial_sample[0] );
    
    for ( vector<unsigned int>::const_iterator sample_iterator = multinomial_sample.begin();
	  sample_iterator != multinomial_sample.end(); sample_iterator++ ) {
      if ( *sample_iterator ) {
	return ( sample_iterator - multinomial_sample.begin() );
      }
    }
    
    return 0;
    
  };

};

/* TODO : is this the right inheritance tree ? */
/* TODO : rename as ProbabilisticSequence ? => would mean inheriting from Sequence */
class ProbabilisticObject: public MultinomialSampler, public StringifiableObject {

 public:
  
  /* compute the probability of this object */
  double probability();

  /* compute the log probability of this object */
  virtual double log_probability() = 0;

};

class CountableProbabilisticObject: public ProbabilisticObject, public CountableObject {

};

#endif
