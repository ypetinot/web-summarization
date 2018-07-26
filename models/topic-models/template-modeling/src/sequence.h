#ifndef __SEQUENCE_H__
#define __SEQUENCE_H__

#include <list>
#include <string>

typedef std::string Token;

/* Note : this is only useful in case we want to ultimately optimize the implementation of Sequence functionality ? */
template< class T > class Sequence: public std::list<T> {

};

class TokenSequence: public std::list<Token> {

public:

TokenSequence(std::string raw_sequence_string):list<Token>() {
/* tokenize raw sequence string */
/* TODO */
}
  
};

#endif
