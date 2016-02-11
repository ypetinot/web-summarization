#ifndef __WORD_LATTICE_H__
#define __WORD_LATTICE_H__

#include <string>

class WordLattice {

 public:

  /* constructor */
  WordLattice();

  /* destructor */
  ~WordLattice();

  /* factory method */
  static WordLattice* buildWordLattice(std::string s);

 private:

  /* root of the lattice */
  WordLatticeToken* root;

  /* end of the lattice */
  WordLatticeToken* end;


};

#endif
