#include "template_model.h"

// TODO : reintroduce PoissonProbabilisticObject(gist->get_corpus(),FLAGS_template_dp_lambda)

/* constructor */
TemplateModel::TemplateModel( const Corpus& corpus , double template_poisson_lambda , double template_dp_alpha , double slot_type_dp_alpha, double gappy_pattern_poisson_lambda , double alpha )
  :_corpus(corpus),_template_dp("templates",template_dp_alpha),
   _slot_type_dp("slot-types",slot_type_dp_alpha),
   _gappy_patterns_lambda(gappy_pattern_poisson_lambda),_gappy_patterns_alpha(alpha),_total_unigram_count(0),_next_slot_type_id(0)
{
  
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

/* get next slot type id */
unsigned int TemplateModel::get_next_slot_type_id() {
  return _next_slot_type_id++;
}

/* get slot types */
vector< GappyPatternProcess* > TemplateModel::get_slot_types() {

#if 0
  vector< string > instance_ids = _slot_type_dp.get_instance_ids();
  
  /* the slot ids are simply indices in  ... */
#endif

  if ( (!_slot_types.size()) || (_slot_types[ _slot_types.size() - 1 ]->count() > 0) ) {

    /* create "new" slot type for sampling purposes */
    /* Note: is this the right place for this ? */
    
    tr1::shared_ptr<GappyPatternProcess> new_process( new GappyPatternProcess( _slot_types.size() , *this ) );
    _slot_types.push_back( new_process );

  }

  vector< GappyPatternProcess* > slot_types;
  for ( vector< tr1::shared_ptr<GappyPatternProcess> >::const_iterator iter = _slot_types.begin(); iter != _slot_types.end(); ++iter ) {
    slot_types.push_back( (*iter).get() );
  }

  return slot_types;

}

/* sample top-level template */
/* gibbs-sampling : other variables (--> inclusion in template at other locations) remain unchanged */
/* MISSING: structure change must factor out the slot types and their color assignments ? */
tr1::shared_ptr<Template> Gist::sample_top_level_template( unsigned int index ) const {

  /* the current template (even though it has been unset at this point) */
  tr1::shared_ptr<Template> current_template = _template;

  /* 1 - get templatic state for the current word */
  int current_word_state = current_template->get_templatic_status( index );
  CHECK( current_word_state == TEMPLATIC_STATUS_SLOT || current_word_state == TEMPLATIC_STATUS_TEMPLATIC );
  
  /* 2 - we make a copy of the current template structure (will be used to create the second sampling candidate) */
  tr1::shared_ptr<Template> flipped_template( new Template( *( current_template.get() ) ) );
  flipped_template->flip_templatic_status( index );
  
  /* vector of template sampling options */
  vector< tr1::shared_ptr<Template> > template_sampling_options;
  vector<double> template_sampling_probabilities;
  
  /* 3 - compute the probability of the templatic transition */
  double template_transition_probability = _corpus.get_template_dp().transition_probability( *( current_template.get() ) , *( flipped_template.get() ) );
  
  /* 4 - compute the (unnormalized) probability of actually including the current word in the top level template */
  double current_template_probability = template_transition_probability * current_template->probability();
  template_sampling_options.push_back( current_template );
  template_sampling_probabilities.push_back( current_template_probability );
  
  /* 5 - compute the (unnormalized) probability of not including the current word in the top level template */
  double flipped_template_probability = ( 1 - template_transition_probability ) * flipped_template->probability();
  template_sampling_options.push_back( flipped_template );
  template_sampling_probabilities.push_back( flipped_template_probability );
  
  /* 6 - sample new template based on state options for the current word */
  unsigned int sampled_index = multinomial_sampler< tr1::shared_ptr<Template> >( template_sampling_options ,
										 template_sampling_probabilities );
  tr1::shared_ptr<Template> sampled_template = template_sampling_options[ sampled_index ];

  /* return sampled template */
  return sampled_template;

}
