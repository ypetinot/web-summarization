#ifndef __LANGUAGE_MODEL_H__
#define __LANGUAGE_MODEL_H__

#include "definitions.h"

#include <google/dense_hash_map>

#define UNIGRAMS_EMPTY_KEY -10000
#define UNIGRAMS_DELETED_KEY -20000

using namespace google;

class LanguageModel {

  /* construct a unigram model from a corpus of word sequences */
  /*
  static initializeLanguageModel(const WordSequenceCorpus<T>& corpus) {

  }
  */
  
};

// TODO : connect to an n-gram server ?
class UnigramLanguageModel: public LanguageModel {

 protected:

  /* unigram counts */
  dense_hash_map<TOKEN, long> _unigram_counts;
  
  /* total unigram count */
  long _total_unigram_count;
  
 public:
  
  // default constructor
  // TODO : provide tokenizer as constructor parameter
  UnigramLanguageModel()
  {
    /* init unigram --> counts */
    _unigram_counts.set_empty_key(UNIGRAMS_EMPTY_KEY);
    _unigram_counts.set_deleted_key(UNIGRAMS_DELETED_KEY); 
  }

  /* get unigram count */
  long get_unigram_count( long word_id ) const {
    dense_hash_map<TOKEN, long>::const_iterator unigram_iter = _unigram_counts.find( word_id );
    if ( unigram_iter != _unigram_counts.end() ) {
      return (*unigram_iter).second;
    }
    return 0;
  }

  /* get total unigram count */
  long get_total_unigram_count() const {
    return _total_unigram_count;
  }

  /* register word instance */
  void register_word_instance( const Sequence& s , long word_id ) {
    _unigram_counts[ word_id ]++;
    _total_unigram_count++;
  }
  
};

#endif
