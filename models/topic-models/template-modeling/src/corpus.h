#ifndef __CORPUS_H__
#define __CORPUS_H__

#include "dirichlet_process.h"
#include "gappy_pattern_process.h"

#include <glog/logging.h>
#include <google/dense_hash_map>
#include <fstream>
#include <tr1/memory>
#include <vector>

using namespace google;
using namespace std;

/* TODO : this probably should not be necessary => try to remove circular dependencies between classes ? */
class Gist;
class Template;

class Corpus {

 public:
  
  /* constructor */
  Corpus( double template_poisson_lambda , double template_dp_alpha , double slot_type_dp_alpha, double gappy_pattern_poisson_lambda , double alpha );

  /* register word instance */
  void register_word_instance( const Gist* gist , long word_id );

  /* gist data loader */
  vector< tr1::shared_ptr<Gist> > load_gist_data(const string& filename);

  /* get total unigram count */
  long get_total_unigram_count() const;

  /* get unigram count */
  long get_unigram_count( long word_id ) const;

  /* get slot type dp */
  DirichletProcess<GappyPatternProcess>& get_slot_type_dp();

  /* get next slot type id */
  unsigned int get_next_slot_type_id();

  /* get slot types */
  vector< GappyPatternProcess* > get_slot_types();
  
 private:

  /* unigram counts */
  dense_hash_map<unsigned int, long> _unigram_counts;
  
  /* total unigram count */
  long _total_unigram_count;

  /* template distribution */
  DirichletProcess<Template> _template_dp;
  
  /* slot type distribution */
  DirichletProcess<GappyPatternProcess> _slot_type_dp;

  /* list of slot types */
  vector< tr1::shared_ptr<GappyPatternProcess> > _slot_types;

  /* next slot type id */
  unsigned int _next_slot_type_id;

  /* alpha - dirichel process concentration parameter */
  double _alpha;

  /* gappy patterns lambda parameter */
  double _gappy_patterns_lambda;
  
  /* gappy patterns alpha parameter */
  double _gappy_patterns_alpha;

};

#endif
