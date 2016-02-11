#ifndef __STRING_ALIGNER_H__
#define __STRING_ALIGNER_H__

#include "WordLattice.h"

class StringAligner {

 protected:

 public:
  
  /* constructor */
  StringAligner();

  /* destructor */
  ~StringAligner();

  /* align pair of word lattices */
  WordLattice* align(const WordLattice& lattice1, const WordLattice& lattice2);

};


#endif
