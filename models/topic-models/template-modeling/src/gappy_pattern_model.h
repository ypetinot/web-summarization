#ifndef __GAPPY_PATTERN_MODEL__
#define __GAPPY_PATTERN_MODEL__

#include "dirichlet_process.h"
#include "gappy_pattern.h"
#include "gappy_pattern_sequence.h"
#include "gappy_pattern_uniform_distribution.h"
#include "model.h"

#include <google/dense_hash_map>

class GappyPatternModel: public Model {

 public:
  
  /* constructor */
 GappyPatternModel(double lambda, double alpha)
   :Model(),_gp_dp("gappy-pattern",alpha) {
    /* init id -> gappy pattern sequence state mapping */
    _gp_sequences.set_empty_key(-1);
    _gp_sequences.set_deleted_key(-2);
  }
  
  /* destructor */
  virtual ~GappyPatternModel() {
    /* nothing for now */
  }

  double log_likelihood(const Corpus& corpus);
  
 protected:
  
  /* the gappy pattern model maintains a Dirichlet Process controlling the (multinomial) distribution of gappy patterns in the corpus sentences */
  /* TODO : should GappyPatternUniformDistribution be a type parameter ? Could it simply be instantiated and passed as an object parameter ? */
  DirichletProcess< GappyPattern , GappyPatternUniformDistribution > _gp_dp;

  /* each sequence in the corpus (as represented by its id) is assigned a template state that describes the overlay of gappy patterns over the sequence */
  // TODO : is this something we would want to be able to serialize ?
  dense_hash_map< long , GappyPatternSequence > _gp_sequences;

  // TODO : if the gappy pattern model becomes part of a larger model (with multiple gappy pattern models) we may need to be able to dynamically add/remove sequences from the corpus. How do we handle this ?
  // TODO : this does not necessarily have to be part of this class, but could be handled by a sub-class providing methods to add/remove corpus entries (should the corpus, as a static entity, still be visible to this class then ?)
  
};

#endif
