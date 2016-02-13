#include "gist.h"

#include "definitions.h"

#include <boost/lexical_cast.hpp>
#include <iostream>
#include <fstream>
#include <gflags/gflags.h>
#include <glog/logging.h>

using namespace std;

/* constructor */
Gist::Gist( Corpus& corpus , const string& url , const vector<long>& w , tr1::shared_ptr<Category> category )
  :_corpus(corpus),w_templatic(w.size(),false),_category(category),_template_initialized(false) {

  this->url = url;
  this->w = w;

  /* init gist */
  _init();

}

/* init */
void Gist::_init() {

  /* nothing - in particular the initialization of the underlying template needs to be delayed until the entire corpus has been read in */
  /* otherwise we cannot compute the base probability as it is based on corpus statistics */

}

/* get url associated with this gist */
string Gist::get_url() const {

  return url;

}

/* return length of this gist (number of words) */
unsigned int Gist::length() const {

  return w.size();

}

/* set templatic marker at the specified index */
void Gist::set_templatic( unsigned int index , bool status ) {

  bool old_status = w_templatic[ index ];
  
  if ( old_status != status ) {

    /* Update model if the template status changes ? */
    /* TODO */

    w_templatic[ index ] = status;

  }

}


/* generate string representation containing the template information */
string Gist::as_string(bool detailed) const {

  if ( detailed ) {
    return _template->as_string();
  }
  else {
    return _template->as_string_log();
  }

}

/* get category */
tr1::shared_ptr<Category> Gist::get_category() const {
  return _category;
}

/* set template */
void Gist::set_template( tr1::shared_ptr<Template> t ) {

  LOG(INFO) << "Registering template for " << get_url() << " ...";

  _template = t;
  
  /* we actually use this template, register it */
  _template->register_with_dp();
  
  LOG(INFO) << "Registered template for " << get_url() << " ...";

}

/* get word at specified index */
long Gist::get_word( unsigned int index ) const {
  
  CHECK_GE( index , 0 );
  CHECK_LE( index , w.size() - 1 );

  return w[ index ];

}

/* get word at specified index (returned as a string object) */
string Gist::get_word_as_string( unsigned int index ) const {
  
  long word_id = get_word( index );
  
  return boost::lexical_cast<std::string>(word_id);

}

/* sample template at specific location */
void Gist::sample_template_at_location( unsigned int i ) {
  
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

/* get corpus */
Corpus& Gist::get_corpus() {

  return _corpus;

}
