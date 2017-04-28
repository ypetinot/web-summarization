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
