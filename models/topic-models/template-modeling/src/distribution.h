#ifndef __DISTRIBUTION_H__
#define __DISTRIBUTION_H__

#include "corpus.h"
#include "object.h"
#include "stringifiable.h"

#include <cmath>
#include <string>
#include <vector>

using namespace std;

// Note : the best solution for now might be to implement this class as an abstract class that can be inherited from (possibly through multiple inheritance) later on
class Distribution {

 public:
  
  /* constructor */
  Distribution( const Corpus& corpus );

  /* probability of a given object (in the corpus ?) */
  virtual double probability() = 0;
  
 protected:

  /* underlying corpus */
  const Corpus& _corpus;
  
};


#if 0
// Note : the motivation for using a templated class here is that we want to be able to describe a distribution over arbitrary (but stringifiable) object types
// TODO : is this the right way of doing this ? why can't we simply inherit from a Distribution object and have the Distribution class expect the presence of a stringify method ?
// TODO : should the Distribution class be seen as a trait ? => this would probably make a lot of sense both semantically and from a coding perspective => we usually want to put a distribution over a collection of objects, but these objects generally exist independently of the distribution itself. From a code perspective, this would mean first creating a class that describes the object and abstracts its behavior and later on we may choose to put a distribution on it (if it's state is unobserved/latent) or to not put a distribution on it (if its state is observed).
template< class T > class Distribution {

 public:
  
  /* constructor */
  Distribution( const Corpus& corpus );

  /* probability of a given object (in the corpus ?) */
  virtual double probability( const T& object ) = 0;
  
 protected:

  /* underlying corpus */
  const Corpus& _corpus;

};
#endif

#endif
