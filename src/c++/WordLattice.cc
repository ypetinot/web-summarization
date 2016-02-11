#include "WordLattice.h"

#include <iostream>
#include <string>
#include <sstream>
#include <algorithm>
#include <iterator>

/* constructor */
WordLattice::WordLattice() {

  /* nothing */
  
}

/* destructor */
WordLattice::~WordLattice() {

  /* nothing */

}

/* factory method */
WordLattice* WordLattice::buildWordLattice(std::string s) {

  /* instantiate new WordLattice */
  WordLattice* wl = new WordLattice();

  istringstream iss(s);

  vector<string> tokens;
  copy(istream_iterator<string>(iss),
       istream_iterator<string>(),
       back_inserter<vector<string> >(tokens));

  for ( vector<string>::iterator iter=tokens.begin(); iter!=tokens.end(); iter++ ) {

    string current = *iter;
    
    /* map token to int */
    int i;
    std::stringstream ss(current);
    ss >> i;

    /* create new WordLatticeToken */
    wl->appendToken(new WordLatticeRegularToken(i));

  } 

  return wl;

}

/* append Token */
void appendToken(WordLatticeToken* t) {
  
  /* where/how do we append tokens ? */

}


/* append Branch */
