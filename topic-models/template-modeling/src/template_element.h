#ifndef __TEMPLATE_ELEMENT_H__
#define __TEMPLATE_ELEMENT_H__

#include <tr1/memory>
#include <vector>

using namespace std;

class Gist;

class TemplateElement {

 public:

  /* constructor */
  TemplateElement( Gist* gist , unsigned int f, unsigned int t );

#if 0
  /* is this element templatic */
  bool is_templatic() const;
#endif

  /* return the length of this element (in number of words) */
  unsigned int length() const;

  /* get word at specified index */
  long get_word( unsigned int index ) const;

  /* get from */
  unsigned int get_from() const;

  /* get to */
  unsigned int get_to() const;

  /* as string */
  string as_string() const;

  /* get word at specified index (returned as a string object) */
  string get_word_as_string( unsigned int index ) const;

  /* get gist */
  Gist* get_gist() const;

 protected:

  /* reference gist */
  Gist* _gist;

  /* from index */
  int from;

  /* to index */
  int to;

};

#endif
