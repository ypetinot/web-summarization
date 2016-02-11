#ifndef __TOKEN_SEQUENCE__
#define __TOKEN_SEQUENCE__

#include <string>
#include <vector>

using namespace std;

class TokenSequence {

private:

  /* underlying set of tokens */
  vector<unsigned int> _tokens;

public:

  /* constructor */
  TokenSequence(vector<unsigned int> tokens);

  /* destructor */
  virtual ~TokenSequence();

  /* create a TokenSequence from a raw string */
  static TokenSequence getTokenSequence( string token_string , string separator );

  /* return this token sequence as a string, given the provided separator */
  string toString( string separator , bool unmap );

  /* return the underlying set of tokens */
  vector<unsigned int> getTokens() const;

};

#endif
