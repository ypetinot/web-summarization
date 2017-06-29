#ifndef __STRINGIFIABLE_H__
#define __STRINGIFIABLE_H__

#include "object.h"

#include <string>

using namespace std;

class StringifiableObject: public Object {

 public:

  /* string version of this object */
  virtual string as_string() const = 0;

};

#if 0
class NaturalLanguageObject: public StringifiableObject {

 public:

}
#endif

class CountableObject: public StringifiableObject {

 public:

  /* get occurence count */
  virtual long count() const;

};


#endif
