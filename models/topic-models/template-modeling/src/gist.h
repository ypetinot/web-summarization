#ifndef __GIST_H__
#define __GIST_H__

// TODO : no reason to have any reference to templates in the Gist class
// TODO : rename to Sequence ?

#include "definitions.h"
#include "sequence.h"
#include "tree.h"

#include <google/dense_hash_map>
#include <set>
#include <string>
#include <tr1/memory>
#include <vector>

#define UNIGRAMS_EMPTY_KEY -10000
#define UNIGRAMS_DELETED_KEY -20000

using namespace std;

/* Each gist maintains its own sampling state and contains: */
/* --> Raw gist data */
/* --> Template object ( managing the top level template as well as the associated template slots ) */

// TODO : do we really need a custom class to model the notion of a sequence of tokens ?
class Gist: public Sequence<long> {

 public:
  
  /* constructor */
  /* TODO : it is probably not relevant to have a reference to Category here */
  Gist( const string& url , const vector<long>& w , tr1::shared_ptr<Category> category );

  /* get url associated with this gist */
  string get_url() const;

  /* get word at specified index */
  long get_word( unsigned int index ) const;

  /* get word at specified index (returned as a string object) */
  string get_word_as_string( unsigned int index ) const;

  /* set templatic marker at the specified index */
  void set_templatic( unsigned int index , bool status );

  /* return length of this gist (number of words) */
  unsigned int length() const;

  /* generate string representation containing the template information */
  string as_string(bool detailed = false) const;

  /* get category */
  tr1::shared_ptr<Category> get_category() const;

  /* unset template */
  void unset_template();

  /* sample template at specific location */
  void sample_template_at_location( unsigned int i );
  
 protected:

  /* init */
  void _init();
  
  /* URL to which this gist belongs */
  string url;

  /* A gist is a sequence (vector) of word ids */
  vector<long> w;

  /* Each word is either templatic or non templatic */
  vector<bool> w_templatic;

  /* Category to which this entry belongs */
  tr1::shared_ptr<Category> _category;

};

#endif
