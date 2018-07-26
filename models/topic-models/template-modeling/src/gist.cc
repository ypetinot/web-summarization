#include "gist.h"

#include "definitions.h"

#include <boost/lexical_cast.hpp>
#include <iostream>
#include <fstream>
#include <gflags/gflags.h>
#include <glog/logging.h>

using namespace std;

/* constructor */
Gist::Gist( const string& url , const vector<long>& w , tr1::shared_ptr<Category> category )
  :_category(category) {

  this->url = url;
  this->w = w;

  /* init gist */
  _init();

}

/* init */
void Gist::_init() {

  /* nothing - in particular the initialization of the underlying template needs to be delayed until the entire corpus has been read in */
  /* otherwise we cannot compute the base probability as it is based on corpus statistics */

}

/* get url associated with this gist */
string Gist::get_url() const {

  return url;

}

/* return length of this gist (number of words) */
unsigned int Gist::length() const {

  return w.size();

}

/* set templatic marker at the specified index */
void Gist::set_templatic( unsigned int index , bool status ) {

  bool old_status = w_templatic[ index ];
  
  if ( old_status != status ) {

    /* Update model if the template status changes ? */
    /* TODO */

    w_templatic[ index ] = status;

  }

}

/* get category */
tr1::shared_ptr<Category> Gist::get_category() const {
  return _category;
}

/* get word at specified index */
long Gist::get_word( unsigned int index ) const {
  
  CHECK_GE( index , 0 );
  CHECK_LE( index , w.size() - 1 );

  return w[ index ];

}

/* get word at specified index (returned as a string object) */
string Gist::get_word_as_string( unsigned int index ) const {
  
  long word_id = get_word( index );
  
  return boost::lexical_cast<std::string>(word_id);

}
