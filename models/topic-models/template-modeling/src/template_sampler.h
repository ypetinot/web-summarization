#ifndef __TEMPLATE_SAMPLER__
#define __TEMPLATE_SAMPLER__

#include "dirichlet_process.h"
#include "gappy_pattern.h"
#include "gist.h"
#include "slot_type_base_distribution.h"
#include "template_alignment.h"
#include "template_base_distribution.h"

#include <tr1/memory>

class TemplateSampler: public MultinomialSampler {

 public:
  
  /* constructor */
  TemplateSampler( Corpus& corpus , const vector< tr1::shared_ptr<Gist> >& gists );

  /* run one sampler iteration */
  void iterate();

  /* check whether the sampler has converged */
  bool has_converged();

  /* return iteration number */
  unsigned int get_iteration_number() const;

  /* dump state (sampler + gists) */
  void dump_state();

  /* dump sampler state */
  void dump_state_sampler();

  /* dump gists state */
  void dump_state_gists();

  /* compute log likelihood of entire corpus */
  double log_likelihood() const;

  /* compute log likelihood for a specific gist */
  double log_likelihood( Gist* gist ) const;

 protected:

  /* reference corpus */
  Corpus& _corpus;

  /* reference data */
  /* TODO: add one more level of abstraction so that the reference data does not have to be stored internally */
  const vector< tr1::shared_ptr<Gist> >& data;

  /* run update for a single data sample */
  void _sample( Gist* data_sample );

  /* sample new top level template for the target gist */
  tr1::shared_ptr<TemplateAlignment> _sample_template( Gist* gist );

  /* process the current slot location */
  void _sample_slot_location( TemplateSlot* slot_location );

  /* sample color (gappy pattern) status of a given word */
  unsigned int _sample_color( Gist* gist , unsigned int index );

  /* return the current count for the specified gappy pattern */
  // TODO : not sure this belongs here, if anything this is a generic functionality that should be provided by the DirichletProcess class (?)
  unsigned int get_gappy_pattern_count( string gappy_pattern_string );

  /* current iteration number */
  unsigned int _iteration_number;

  /* sample slot word pattern */
  void _sample_slot_word_pattern( Gist* gist , unsigned int index );

  /* resample all slot types for the target gist's template */
  void _sample_template_slot_types( Gist* gist );


};

#endif
