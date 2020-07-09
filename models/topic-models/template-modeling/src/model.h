#ifndef __MODEL_H__
#define __MODEL_H__

#include <list>
using namespace std;

template<class T> class Model {

 public:

  /* probability assigned by model to particular event */
  virtual double log_probability(T event) const = 0;

  double log_likelihood(const list<T>& events) const {

    double log_likelihood = 0.0;
    for ( typename list<T>::const_iterator iter = events.begin() ; iter != events.end() ; ++iter ) {
      log_likelihood += log_probability( *iter );
    }

    return log_likelihood;
  
  }

  
};

#endif
