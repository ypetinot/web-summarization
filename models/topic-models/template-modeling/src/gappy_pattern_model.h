#ifndef __GAPPY_PATTERN_MODEL__
#define __GAPPY_PATTERN_MODEL__

#include "dirichlet_process.h"
#include "gappy_pattern.h"
#include "gappy_pattern_sequence.h"
#include "gappy_pattern_uniform_distribution.h"
#include "model.h"
#include "sequence.h"

#include <google/dense_hash_map>

template< class T > class GappyPatternModel: public Model< WordSequence<T> > {

 public:
  
  /* constructor */
 GappyPatternModel(const WordSequenceCorpus<T>& corpus, double lambda, double alpha)
   :Model< WordSequence<T> >(),
    //_corpus(corpus),
    _gp_uniform_distribution(corpus,lambda),
    _gp_dp("gappy-pattern",alpha,_gp_uniform_distribution) {
    /* init id -> gappy pattern sequence state mapping */
    _gp_sequences.set_empty_key(-1);
    _gp_sequences.set_deleted_key(-2);
  }
  
  /* destructor */
  virtual ~GappyPatternModel() {
    /* nothing for now */
  }

  /* probability of a particular sequence under this model */
  double log_probability(WordSequence<T> sequence) const {
    /* TODO */
    assert(0);
    return 0.0;
  }
  
 protected:
  
  /* the gappy pattern model maintains a Dirichlet Process controlling the (multinomial) distribution of gappy patterns in the corpus sentences */
  /* TODO : should GappyPatternUniformDistribution be a type parameter ? Could it simply be instantiated and passed as an object parameter ? */
  /* TODO : should the GappyPatternUniformDistribution be instantiated prior to instantiating the model ? => no, this should built by default */
  /* TODO : is this used only during training or during inference as well ? => latter and we may say that --- generally --- the (reference) corpus remains the same between training and inference => corpus is an integral field of the model and thus *can* also be specified at construction time */
  const GappyPatternUniformDistribution<T> _gp_uniform_distribution;
  const DirichletProcess< GappyPattern > _gp_dp;

  /* each sequence in the corpus (as represented by its id) is assigned a template state that describes the overlay of gappy patterns over the sequence */
  // TODO : is this something we would want to be able to serialize ?
  dense_hash_map< long , GappyPatternSequence<T> > _gp_sequences;

  // TODO : if the gappy pattern model becomes part of a larger model (with multiple gappy pattern models) we may need to be able to dynamically add/remove sequences from the corpus. How do we handle this ?
  // TODO : this does not necessarily have to be part of this class, but could be handled by a sub-class providing methods to add/remove corpus entries (should the corpus, as a static entity, still be visible to this class then ?)
  
};

#endif
