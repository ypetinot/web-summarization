#include "template_alignment.h"
#include "probabilistic_object.h"

#include "gist.h"

#include <glog/logging.h>

/* constructor */
TemplateAlignment::TemplateAlignment( const Gist* gist )
  :_gist(gist),_templatic_status(gist->length(),0) {

  /* A valid gist must be provided */
  CHECK( gist != NULL );

  /* --> random initialization */
  _init();

}

/* get length of this alignment */
unsigned int TemplateAlignment::length() const {

  /* the templatic status map should have the same length as the underlying gist */
  CHECK( _templatic_status.size() == _gist->length() );

  return _templatic_status.size();

}

/* get underlying gist */
const Gist* TemplateAlignment::get_gist() const {

  return _gist;

}

/* string representation of this alignment */
string TemplateAlignment::as_string() const {

  string representation;

  for ( vector<short int>::const_iterator iter = _templatic_status.begin(); iter != _templatic_status.end(); ++iter ) {
    
    if ( iter != _templatic_status.begin() ) {
      representation.append( " " );
    }
    
    if ( *iter ) {
      representation.append( _gist->get_word_as_string( iter - _templatic_status.begin() ) );
    }
    else {
      representation.append( "_" );
    }

  }

  return representation;

}
