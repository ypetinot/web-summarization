#include "TokenSequence.hh"

#include <iostream>
#include <sstream>

using namespace std;

/* constructor */
TokenSequence::TokenSequence(vector<unsigned int> tokens)
  :_tokens(tokens)
{
  /* nothing for now */
}

/* destructor */
TokenSequence::~TokenSequence() {
  /* nothing for now */
}

/* create a TokenSequence from a raw string */
TokenSequence TokenSequence::getTokenSequence(string token_string, string separator) {

  /* split token_string according to separator */
  vector<unsigned int> token_ids;
  istringstream iss(token_string);
  string token;
  while ( getline(iss, token, separator[0]) ) {
    
    /* convert token to a numeric value */
    unsigned int token_id;
    istringstream iss2(token);
    iss2 >> token_id;

    token_ids.push_back(token_id);

  }

  /* create new TokenSequence instance */
  TokenSequence tokenSequence(token_ids);

  /* return the newly created token sequence */
  return tokenSequence;

}

 /* return this token sequence as a string, given the provided separator */
string TokenSequence::toString(string separator,bool unmap) {
  
  ostringstream oss;
  for(vector<unsigned int>::iterator iter=_tokens.begin(); iter !=_tokens.end(); iter++) {
    if ( iter != _tokens.begin() ) {
      oss << separator;
    }
    oss << unmap ? to_word( *iter ) : *iter;
  }

  return oss.str();

}

/* return the underlying set of tokens */
vector<unsigned int> TokenSequence::getTokens() const {
  return _tokens;
}
