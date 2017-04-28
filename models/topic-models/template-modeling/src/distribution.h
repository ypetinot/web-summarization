#ifndef __DISTRIBUTION_H__
#define __DISTRIBUTION_H__

#include "object.h"
#include "stringifiable.h"

#include <cmath>
#include <string>
#include <vector>

using namespace std;

class Corpus;

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
