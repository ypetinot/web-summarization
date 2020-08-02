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

using namespace std;

/* Each gist maintains its own sampling state and contains: */
/* --> Raw gist data */
/* --> Template object ( managing the top level template as well as the associated template slots ) */

// Class pairs a sequence object with meta-attributes (for now a URL and a category)
class SequenceRecord {

 public:
  
  /* constructor */
  SequenceRecord( const string& u , const Sequence& s , tr1::shared_ptr<Category> category )
    :url(u),sequence(s),_category(category) {
    /* init record */
    _init();
  }
  
  /* get category */
  tr1::shared_ptr<Category> get_category() const {
    return _category;
  }

  /* sequence */
  // TODO : should this really be a const reference ? (i.e. how do we enable record-keeping at the model level ?)
  const Sequence& sequence;
  
 protected:

  /* init */
  void _init() {
    /* nothing - in particular the initialization of the underlying template needs to be delayed until the entire corpus has been read in */
    /* otherwise we cannot compute the base probability as it is based on corpus statistics */
  }
  
  /* URL to which this gist belongs */
  const string url;
  
  /* Category to which this entry belongs */
  tr1::shared_ptr<Category> _category;

};

#endif
