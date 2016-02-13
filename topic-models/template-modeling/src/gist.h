#ifndef __GIST_H__
#define __GIST_H__

#include "corpus.h"
#include "gappy_pattern.h"
#include "probabilistic_object.h"
#include "template.h"
#include "tree.h"

#include <google/dense_hash_map>
#include <set>
#include <string>
#include <tr1/memory>

#define UNIGRAMS_EMPTY_KEY -10000
#define UNIGRAMS_DELETED_KEY -20000

using namespace std;

class GappyPattern;

/* Each gist maintains its own sampling state and contains: */
/* --> Raw gist data */
/* --> Template object ( managing the top level template as well as the associated template slots ) */

class Gist: public MultinomialSampler {

 public:
  
  /* constructor */
  Gist( Corpus& corpus , const string& url , const vector<long>& w , tr1::shared_ptr<Category> category );

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

  /* get template */
  tr1::shared_ptr<Template> get_template();

  /* unset template */
  void unset_template();
  
  /* set template */
  void set_template( tr1::shared_ptr<Template> t );

  /* (re)-sample top level template for this gist */
  void sample_template();

  /* get corpus */
  Corpus& get_corpus();

 protected:

  /* init */
  void _init();
  
  /* URL to which this gist belongs */
  string url;

  /* A gist is a sequence (vector) of word ids */
  vector<long> w;

  /* Each word is either templatic or non templatic */
  vector<bool> w_templatic;

  /* Corpus to which this entry belongs */
  Corpus& _corpus;

  /* Category to which this entry belongs */
  tr1::shared_ptr<Category> _category;

  /* Current template for this gist */
  tr1::shared_ptr<Template> _template;

  /* has the associated template been initialized */
  bool _template_initialized;

  /* sample top-level template */
  tr1::shared_ptr<Template> sample_top_level_template( unsigned int index ) const;

};

#endif
