#ifndef __MULTIPLE_STRING_ALIGNER_H__
#define __MULTIPLE_STRING_ALIGNER_H__

#include "StringAligner.h"

#include <vector>

using namespace std;

class MultipleStringAligner: public StringAligner {

 public:

  /* constructor */
  MultipleStringAligner();

  /* destructor */
  virtual ~MultipleStringAligner();

  /* align vector of word lattices */
  WordLattice* align(vector<WordLattice> lattices);

};

#endif
