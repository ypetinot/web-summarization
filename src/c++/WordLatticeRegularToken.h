#ifndef __WORD_LATTICE_REGULAR_TOKEN_H__
#define __WORD_LATTICE_REGULAR_TOKEN_H__

#include <WordLatticeToken>

class WordLatticeRegularToken: public WordLatticeToken {

 public:

  /* constructor */
  WordLatticeRegularToken(int tid);

  /* destructor */
  ~WordLatticeRegularToken();

 private:

  /* underlying token id */
  int token_id;

};

#endif
