#include "template_element.h"

#include <boost/lexical_cast.hpp>
#include "gist.h"

/* constructor */
TemplateElement::TemplateElement( const Gist& gist,
				  //const TemplateElement parent,
				  unsigned int f, unsigned int t )
  :_gist(gist),
   //_parent(parent),
   from(f),to(t) {

  /* nothing for now */

}

/* return the length of this element (in number of words) */
unsigned int TemplateElement::length() const {
  return ( to - from + 1 );
}

#if 0
/* is this element templatic */
bool TemplateElement::is_templatic() const {
  return true;
}
#endif

/* get word at specified index */
long TemplateElement::get_word( unsigned int index ) const {
  
  unsigned int true_index = from + index;
  
  return _gist.get_word( true_index );

}

/* get from */
unsigned int TemplateElement::get_from() const {
  return from;
}

/* get to */
unsigned int TemplateElement::get_to() const {
  return to;
}

/* as string */
string TemplateElement::as_string() const {

  string representation;
 
  for (unsigned int i=from; i<=to; i++) {
    representation.append( get_word_as_string( from ) );  
  }

  return representation;

}

/* get word at specified index (returned as a string object) */
string TemplateElement::get_word_as_string( unsigned int index ) const {
  
  unsigned int real_index = from + index ;
  
  return _gist.get_word_as_string( real_index );

}

/* get gist */
const Gist& TemplateElement::get_gist() const {
  return _gist;
}
