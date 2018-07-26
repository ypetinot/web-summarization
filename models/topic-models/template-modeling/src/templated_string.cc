#include "templated_string.h"

TemplatedString:TemplatedString(string raw_string)
  :Gist(raw_string),_template_initialized(false),w_templatic(this.size(),false) {

}

/* sample template at specific location */
void TemplatedString::sample_template_at_location( unsigned int i ) {
  
  LOG(INFO) << "\n\n";
  LOG(INFO) << "Resampling template for " << get_url() << " - transition at location " << i;
  
  /* unset template */
  if ( _template_initialized ) {
    
    /* Note : is dp unregistration needed ? */
    /* --> it is because, even though we transition at the token level, we use statistics about complete template constructs to sample the next state */
    /* Thus (is this really sound ?) the current template state should not affect the sampling operation */
    
    /* template sampling */
    /* --> we are following an approach along the lines of that used in \cite{Gimpel20xx} */
    /* ==> we unregister at the specific location ? ==> what would this mean ? */
    /* ==> in/out template ==> two outcomes */
    /* ==> count for each outcome ==> this is our multinomial ==> so full unregistration */
    /* probability of slot assignment = p_dp( type ) * p( type | content ) */
    /* p( type | content ) \prop p( content | type ) * p( type ) */
    

    LOG(INFO) << "Unregistering template for " << get_url() << " ...";
    _template->unregister_with_dp();
    LOG(INFO) << "Unregistered template for " << get_url() << " ...";
    
  }
  else {
    
    /* TODO: initialization ? */
    
    /* if the template has not been set yet, we initialize randomly */
    
    /* random initialization */
    tr1::shared_ptr<Template> random_template( new Template( this ) );
    _template = random_template;
    
    /* we need to register this template with the underlying dp (?) */
    set_template( random_template );
    
    /* this gist's template has been initialized ! */
    _template_initialized = true;
    
  }
  
  /* what is the simplest (least technically demanding) initialization ? */
  /* --> all templatic ? requires pre-registration ? */
  
  CHECK( _template_initialized );
  
  /* ************************************************************************************* */
  /* Gibbs sampling strategy: we resample template all other variables remaining identical */
  /* ************************************************************************************* */
  
  /* sample template based on a transition for the current word */
  tr1::shared_ptr<Template> sampled_template = sample_top_level_template( i );
  
  /* next step depends on whether the template structure changed */ 
  if ( sampled_template != _template ) {
    
    /* If the top-level template changed, we resample the slot types */
    LOG(INFO) << "\tTemplate structure changed for " << get_url() << " - resampling slot types ...";
    sampled_template->sample_slot_types_and_register();
    
  }
  else {
    
    LOG(INFO) << "\tTemplate structure unchanged for " << get_url() << " - sampling in-slot coloring ...";
    
    if ( sampled_template->is_slot( i ) ) {
      
      /* not for now - let's talk about this with Daichi */
      /* sample type, then color --> does this mean we're importing the coloring from the old type ? */
      
      /* we are resampling the color of the target word within the current slot */
      /* TODO: this should be abstracted properly - too much detail at this level */
      sampled_template->get_slot_at_word_location( i )->sample_color( i );
      
    }
    
  }
  
  /* set template - this triggers sub-sampling steps as necessary (managed through Template class) ??? */
  set_template( sampled_template );

}

/* generate string representation containing the template information */
string TemplatedString::as_string(bool detailed) const {

  if ( detailed ) {
    return _template->as_string();
  }
  else {
    return _template->as_string_log();
  }

}

/* set template */
void TemplatedString::set_template( tr1::shared_ptr<Template> t ) {

  LOG(INFO) << "Registering template for " << get_url() << " ...";

  _template = t;
  
  /* we actually use this template, register it */
  _template->register_with_dp();
  
  LOG(INFO) << "Registered template for " << get_url() << " ...";

}

/* (re)-sample top level template for this gist */
/* strategy: sampling is iterative, no macro steps (***no full object registering/unregistering***) */
/* strategy: sampling is tree-based, lower level decisions must be factored out ?? (to be confirmed) */
/* instead only local transitions (i.e. Gibbs Sampling) */
/* top-down sampling : changes at the top-level trigger lower level updates
/* top-dow registration ok if Gibbs Sampling */
void Gist::sample_template() {
  
  LOG( INFO ) << "\t\t" << "Starting sampling procedure for " << get_url();

  /* Iterate over each word in this gist and trigger sub-sampling as necessary */
  for (unsigned int i = 0; i < length(); i++) {

    sample_template_at_location( i );

  }

}
