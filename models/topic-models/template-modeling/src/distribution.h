#ifndef __DISTRIBUTION_H__
#define __DISTRIBUTION_H__

#include "object.h"
#include "stringifiable.h"

#include <cmath>
#include <string>
#include <vector>

using namespace std;

#if 0
// Note : the best solution for now might be to implement this class as an abstract class that can be inherited from (possibly through multiple inheritance) later on
class Distribution {

 public:
  
  /* constructor */
  Distribution();

  /* probability of a given object (in the corpus ?) */
  virtual double probability() = 0;
  
 protected:
  
};
#endif

// Note : the motivation for using a templated class here is that we want to be able to describe a distribution over arbitrary (but stringifiable) object types
// TODO : should the Distribution class be made aware of the space from which events are drawn, or is it sufficient to achieve this through some form of event registration ?
// TODO : is this the right way of doing this ? why can't we simply inherit from a Distribution object and have the Distribution class expect the presence of a stringify method ?
// TODO : should the Distribution class be seen as a trait ? => this would probably make a lot of sense both semantically and from a coding perspective => we usually want to put a distribution over a collection of objects, but these objects generally exist independently of the distribution itself. From a code perspective, this would mean first creating a class that describes the object and abstracts its behavior and later on we may choose to put a distribution on it (if it's state is unobserved/latent) or to not put a distribution on it (if its state is observed).
template< class T > class Distribution {

 public:
  
  /* constructor */
  Distribution();

  /* probability of a given event */
  double probability( const T& event ) {
    return exp( log_probability( event ) );
  }

  /* log probability of a given event */
  virtual double log_probability( const T& event ) = 0;
  
 protected:

};

#endif
