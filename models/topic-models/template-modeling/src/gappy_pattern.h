#ifndef __GAPPY_PATTERN_H__
#define __GAPPY_PATTERN_H__

#include "corpus.h"
#include "probabilistic_object.h"
#include "stringifiable.h"
#include "template_element.h"

#include <google/dense_hash_map>
#include <string>
#include <vector>
#include <set>
#include <stack>
#include <tr1/memory>

#include "hashing.h"

using namespace std;
using namespace google;

/* The GappyPattern class abstracts the notion of a single gappy pattern --- i.e. a gap-including sequence potentially corresponding to a sub-sequence of a full-fledged sentence --- and provides elementary operations to iteratively transform the state of the gappy pattern */

class GappyPattern: public PoissonProbabilisticObject, public StringifiableObject {

 public:

  /* constructor */
  // TODO : a gappy pattern should probably be initialized with a target length
  GappyPattern();

  /* destructor */
  ~GappyPattern();
  
  /* add word to pattern */
  const GappyPattern& add_word( unsigned int index );

  /* add gap to pattern */
  const GappyPattern& add_gap( unsigned int index );

  /* get words */
  vector<long> get_words() const;

  /* number of words getter */
  unsigned int get_number_of_words() const;

  /* return the status of the word at the specified index */
  const bool get_pattern_marker( unsigned int i ) const;

  /* insert word at the specified location */
  const GappyPattern& insert_word( unsigned int i );

  /* get pattern as a string */
  string as_string() const;

  /* get pattern as a string (log content) */
  string as_string_log() const;
  
 protected:

  /* remove word from pattern */
  const GappyPattern& remove_word( unsigned int index );

  /* set pattern marker */
  void set_pattern_marker( unsigned int index , bool status );

  /* pattern markers --> 1 if in pattern, 0 otherwise (i.e. belongs to a gap) */
  vector<unsigned short int> _pattern_markers;

  /* number of words in this pattern */
  unsigned int number_of_words;

  /* check index validity */
  bool _valid_index( unsigned int index ) const;

  /* get pattern as a string with many options */
  string _as_string() const;

};

#endif
