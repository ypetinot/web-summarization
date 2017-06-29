#include "template_model.h"

// TODO : reintroduce PoissonProbabilisticObject(gist->get_corpus(),FLAGS_template_dp_lambda)

/* constructor */
TemplateModel::TemplateModel( const Corpus& corpus )
  :_corpus(corpus),_template_dp() {

  /* nothing */
  
}

/* get underlying dp */
DirichletProcess< Template , Distribution<Template> >& TemplateModel::_get_underlying_dirichlet_process() const {
  return _template_dp;
}

/* get template dp */
DirichletProcess<Template>& TemplateModel::get_template_dp() {
  return _template_dp;
}

/* fit model against corpus */
void TemplateModel::train() {

  /* 1 - read training data */
  LOG(INFO) << "Loading training data ...";
  vector< tr1::shared_ptr<Gist> > gists = _corpus.load_gist_data( FLAGS_gist_data );

  /* 2 - train model */
  LOG(INFO) << "Training model ...";
  tr1::shared_ptr<TemplateSampler> ts( new TemplateSampler( _corpus , gists ) );
  while ( ! ts->has_converged() && ts->get_iteration_number() < FLAGS_max_iterations ) {
    
    ts->iterate();
    ts->dump_state();
 
  }
   
}

/* register template with underlying dp */
void TemplateModel::register_template_with_dp( const Template& template_instance ) {

  /* register slot instances in this template */
  /* TODO: slot iterator ? */
  for (unsigned int i = 0; i<_slots.size(); i++) {
    
    if ( _templatic_status[ i ] == TEMPLATIC_STATUS_SLOT ) {
      
      tr1::shared_ptr<TemplateSlot> current_slot = _slots[ i ];
      GappyPatternProcess* current_slot_type = current_slot->get_type();

      /* update slot type dp */
      _gist->get_corpus().get_slot_type_dp().add_instance( * current_slot_type );

      /* register slot coloring */
      /* pb: what does it mean if we register in bulk ? --> artificially inflate certain colorings ? */
      current_slot->register_coloring();

      i += current_slot->length();

    }

  }
  
  /* register template itself */
  _get_underlying_dirichlet_process().add_instance( template_instance );

}

/* unregister template with underlying dp */
void TemplateModel::unregister_template_with_dp( const Template& template_instance ) {

  /* unregister template itself */
  _get_underlying_dirichlet_process().remove_instance( template_instance );

  /* unregister slots appearing inside the template (if any) */
  /* TODO: create proper slot iterator ? */
  for (unsigned int i = 0; i<_slots.size(); i++) {
    
    if ( _templatic_status[ i ] == TEMPLATIC_STATUS_SLOT ) {
      
      tr1::shared_ptr<TemplateSlot> current_slot = _slots[ i ];
      GappyPatternProcess* current_slot_type = current_slot->get_type();

      /* TODO: can the current slot type even be NULL ? */ 
      if ( current_slot_type != NULL ) {
    
	/* remove the current instance from the slot type dp */
	_gist->get_corpus().get_slot_type_dp().remove_instance( * current_slot_type );
    
	/* register slot coloring */
	/* pb: what does it mean if we register in bulk ? --> artificially inflate certain colorings ? */
	current_slot->unregister_coloring();

#if 0
	/* we're not using shared_ptr's for this */
	if ( (_slot_type->count() == 1) ) {
	  delete _slot_type;
	}
#endif
	
      }
      
      i += current_slot->length();
      
    }
    
  }

}
