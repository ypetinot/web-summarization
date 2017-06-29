#ifndef __CORPUS_H__
#define __CORPUS_H__

#include <glog/logging.h>
#include <google/dense_hash_map>
#include <fstream>
#include <tr1/memory>
#include <vector>

using namespace google;
using namespace std;

/* TODO : this probably should not be necessary => try to remove circular dependencies between classes ? */
class Gist;

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

 private:

  /* unigram counts */
  dense_hash_map<unsigned int, long> _unigram_counts;
  
  /* total unigram count */
  long _total_unigram_count;

};

#endif
