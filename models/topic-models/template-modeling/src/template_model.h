#ifndef __TEMPLATE_MODEL_H__
#define __TEMPLATE_MODEL_H__

typedef DirichletProcess< GappyPatternProcess , TemplateSlotUniformDistribution > TemplateSlotProcess;

class TemplateModel {

 protected:

  // TODO : should this really be a field in this class ? => turn this into a parameter for the train method ?
  /* corpus on which the model is to be trained */
  const Corpus& _corpus;

  // Note : uniform base (prior) distribution => all structurally acceptable templates are (initially) equiprobable
  DirichletProcess< Template , TemplateUniformDistribution > _template_dp;
  
  /* get template dp */
  //DirichletProcess< Template , TemplateUniformDistribution >& get_template_dp();
  DirichletProcess< Template , Distribution<Template> >& get_template_dp();

  /* get slot type dp */
  DirichletProcess< GappyPatternProcess  >& get_slot_type_dp();

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* get next slot type id */
  unsigned int get_next_slot_type_id();

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* get slot types */
  vector< GappyPatternProcess* > get_slot_types();

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* template distribution */
  DirichletProcess<Template> _template_dp;
  
  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* slot type distribution */
  DirichletProcess<GappyPatternProcess> _slot_type_dp;

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* list of slot types */
  vector< tr1::shared_ptr<GappyPatternProcess> > _slot_types;

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* next slot type id */
  unsigned int _next_slot_type_id;

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* alpha - dirichel process concentration parameter */
  double _alpha;

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* gappy patterns lambda parameter */
  double _gappy_patterns_lambda;

  // TODO : this used to be in corpus.h , make sure it makes sense here
  /* gappy patterns alpha parameter */
  double _gappy_patterns_alpha;
  
 public:

  /* fit model against corpus */
  void train();

  /* register template with underlying dp */
  void register_template_with_dp( const Template& template_instance );
  
  /* unregister template with underlying dp */
  void unregister_template_with_dp( const Template& template_instance );

  /* TODO : does this really belong here ? */
  /* template probability (full configuration, including slots and their fillers) */
  double log_probability( const Template& template_instance );
  
}

#endif
