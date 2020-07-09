#ifndef __SEQUENCE_H__
#define __SEQUENCE_H__

#include <list>
#include <string>

typedef std::string Token;

/* Note : this is only useful in case we want to ultimately optimize the implementation of Sequence functionality ? */
template< class T > class Sequence: public std::list<T> {

};

template< class T > class TokenSequence: public std::list<T> {

public:

 TokenSequence(std::string raw_sequence_string):std::list<T>() {
    /* tokenize raw sequence string */
    /* TODO */
  }

  /* default constructor - only needed so that TokenSequence (and its descendant classes) can be used with containers */
  // TODO : make this method protected
  TokenSequence() {
    /* nothing */
  }
  
 protected:

  
};

#endif
