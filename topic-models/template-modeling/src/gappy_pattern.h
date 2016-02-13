#ifndef __GAPPY_PATTERN_H__
#define __GAPPY_PATTERN_H__

#include "corpus.h"
#include "dirichlet_process.h"
#include "multinomial_distribution.h"
#include "probabilistic_object.h"
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

class TemplateSlot;

class GappyPattern: public PoissonProbabilisticObject, public TemplateElement {

 public:

  /* constructor */
  GappyPattern( const TemplateSlot& ts );

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

  /* get number of arrangements */
  long get_number_of_arrangements() const;

  /* compute the probability of this object */
  virtual double log_probability();

 protected:

  /* parent/target location */
  const TemplateSlot& _gp_location;

  /* remove word from pattern */
  const GappyPattern& remove_word( unsigned int index );

  /* set pattern marker */
  void set_pattern_marker( unsigned int index , bool status );

  /* pattern markers --> 1 if in pattern, 0 otherwise (i.e. belongs to a gap) */
  vector<unsigned short int> _pattern_markers;

  /* number of words in this pattern */
  unsigned int number_of_words;

  double _base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements );

  /* check index validity */
  bool _valid_index( unsigned int index ) const;

  /* get pattern as a string with many options */
  string _as_string() const;

};

class GappyPatternProcess: public CountableProbabilisticObject {
//: public MultinomialDistribution {
  
 public:

  /* constructor */
  GappyPatternProcess( unsigned int id , Corpus& corpus );

  /* Increments count for the target gappy pattern */
  unsigned int _increment_pattern_count( const GappyPattern& gappy_pattern );

  /* Decrements count for the target gappy pattern */
  unsigned int _decrement_pattern_count( const GappyPattern& gappy_pattern );

  /* dump process state */
  void dump_state( string filename );
  
  /* compute the probability of a gappy pattern */
  double _compute_probability_gappy_pattern_update( GappyPattern& gp , unsigned int candidate_location );
  
  /* compute probability of gap/unigram arrangement in gappy pattern */
  double _compute_gappy_pattern_arrangement_probability( const GappyPattern* gappy_pattern ) const;
  
  /* get total instances count */
  long get_total_instances() const;

  /* compute probability of introducing a new color for the target word */
  double _probability_new_color( GappyPattern& pattern );

  /* string version of this object */
  string as_string() const;

  /* string version of this object (log content) */
  string as_string_log() const;

  /* get occurence count */
  virtual long count() const;

  /* log probability */
  virtual double log_probability();

 protected:

  /* id */
  unsigned int _id;

  /* Underlying Dirichlet Process */
  /* TODO: should we simply inherit from DirichletProcess ? */
  DirichletProcess<GappyPattern> _gappy_pattern_dp;

  /* corpus */
  Corpus& _corpus;

  /* gappy pattern counts */
  dense_hash_map<string, unsigned int, MurmurHash2, eqstring> m_gappy_pattern_counts;

  /* get poisson probability */
  double get_poisson_log_probability( unsigned int n_words );

};

#endif
