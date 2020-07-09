#ifndef __GIST_H__
#define __GIST_H__

// TODO : no reason to have any reference to templates in the Gist class
// TODO : rename to Sequence ?

#include "definitions.h"
#include "sequence.h"
#include "tree.h"

#include <boost/lexical_cast.hpp>
#include <google/dense_hash_map>
#include <set>
#include <string>
#include <tr1/memory>
#include <vector>

using namespace std;

/* Each gist maintains its own sampling state and contains: */
/* --> Raw gist data */
/* --> Template object ( managing the top level template as well as the associated template slots ) */

// TODO : do we really need a custom class to model the notion of a sequence of tokens ?
template<class T> class Gist: public TokenSequence<T> {

 public:
  
  /* constructor */
  /* TODO : it is probably not relevant to have a reference to Category here */
  Gist( const string& url , const vector<T>& w , tr1::shared_ptr<Category> category )
    :_category(category) {
    this->url = url;
    this->w = w;
    /* init gist */
    _init();
  }
  
  /* get url associated with this gist */
  string get_url() const {
    return url;
  }

  /* get word at specified index */
  T get_word( unsigned int index ) const {
    CHECK_GE( index , 0 );
    CHECK_LE( index , w.size() - 1 );
    return w[ index ];
  }

  /* get word at specified index (returned as a string object) */
  string get_word_as_string( unsigned int index ) const {
    T word_id = get_word( index );
    return boost::lexical_cast<std::string>(word_id);
  }
  
  /* set templatic marker at the specified index */
  void set_templatic( unsigned int index , bool status ) {
    bool old_status = w_templatic[ index ];
    if ( old_status != status ) {
      /* Update model if the template status changes ? */
      /* TODO */
      w_templatic[ index ] = status;
    }
  }
  
  /* return length of this gist (number of words) */
  unsigned int length() const {
    return w.size();
  }
  
  /* generate string representation containing the template information */
  string as_string(bool detailed = false) const;

  /* get category */
  tr1::shared_ptr<Category> get_category() const {
    return _category;
  }
  
  /* unset template */
  void unset_template();

  /* sample template at specific location */
  void sample_template_at_location( unsigned int i );
  
 protected:

  /* init */
  void _init() {
    /* nothing - in particular the initialization of the underlying template needs to be delayed until the entire corpus has been read in */
    /* otherwise we cannot compute the base probability as it is based on corpus statistics */
  }
  
  /* URL to which this gist belongs */
  string url;

  /* A gist is a sequence (vector) of word ids */
  vector<T> w;
  
  /* Each word is either templatic or non templatic */
  vector<bool> w_templatic;

  /* Category to which this entry belongs */
  tr1::shared_ptr<Category> _category;

};

#endif
