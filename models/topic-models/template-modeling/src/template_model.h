#ifndef __TEMPLATE_MODEL_H__
#define __TEMPLATE_MODEL_H__

#if 0
_template_base_distribution(*this,template_poisson_lambda),_slot_type_base_distribution(*this),
#endif

typedef DirichletProcess< GappyPatternProcess , TemplateSlotUniformDistribution > TemplateSlotProcess;
typedef DirichletProcess< Template , TemplateUniformDistribution > MultiSlotTypeTemplateDP;

class MultiSlotTypeTemplateModel: public Model {

 protected:

  // Note : uniform base (prior) distribution => all structurally acceptable templates are (initially) equiprobable
  MultiSlotTypeTemplateDP _template_dp;
  
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

  MultiSlotTypeTemplateModel(double template_poisson_lambda , double template_dp_alpha , double slot_type_dp_alpha, double gappy_pattern_poisson_lambda , double alpha);
  
  /* fit model against corpus */
  // Note: the corpus is not a field of this class so we can easily serialize/deserialize the model
  // TODO : problem is that this will not allow us to easily associate a state with the corpus object
  void train(Corpus& corpus);

  /* register template with underlying dp */
  void register_template_with_dp( const Template& template_instance );
  
  /* unregister template with underlying dp */
  void unregister_template_with_dp( const Template& template_instance );

  /* TODO : does this really belong here ? */
  /* template probability (full configuration, including slots and their fillers) */
  double log_probability( const Template& template_instance );

};
  
#endif
