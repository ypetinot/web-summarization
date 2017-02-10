#ifndef __DISTRIBUTION_H__
#define __DISTRIBUTION_H__

#include "object.h"
#include "stringifiable.h"

#include <cmath>
#include <string>
#include <vector>

using namespace std;

class Corpus;

class Distribution {

 public:

  /* constructor */
  Distribution( const Corpus& corpus );

 protected:

  /* underlying corpus */
  const Corpus& _corpus;

};

#endif
