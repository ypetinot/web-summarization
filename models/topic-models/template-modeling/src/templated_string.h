#ifndef __TEMPLATED_STRING_H__
#define __TEMPLATED_STRING_H__

#include <string>

using namespace std;

/* Abstracts the notion of a template overlaid on an existing string */
/* Controls the space of acceptable templates and the transitions between template configurations for the underlying string */
class TemplatedString: public Gist {
  
 protected:

  /* tokenized version of the original string */
  string[] _tokenized_string;

  /* templatic status of individual words/tokens */
  bool[] _templatic_status;

 public:

  TemplatedString(string raw_string);
  
}

#endif
