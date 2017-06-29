#ifndef __GAPPY_PATTERN_PROCESS__
#define __GAPPY_PATTERN_PROCESS__

#include "dirichlet_process.h"
#include "gappy_pattern.h"
#include "gappy_pattern_uniform_distribution.h"

/* The GappyPatternProcess class abstracts the notion of a (Dirichlet) process controlling the creation (is this the right word ?) of gappy patterns */

// TODO : is this class fundamentally different from a Dirichlet process ?
typedef DirichletProcess<GappyPattern,GappyPatternUniformDistribution> GappyPatternProcess;

#if 0
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

#endif
