#include "template_alignment.h"
#include "template_sampler.h"

#include <boost/lexical_cast.hpp>
#include <iostream>
#include <fstream>
#include <glog/logging.h>

/* constructor */
TemplateSampler::TemplateSampler( Corpus& corpus , const vector< tr1::shared_ptr<Gist> >& gists )
  :_corpus(corpus),data(gists),_iteration_number(0) {

  for ( vector< tr1::shared_ptr<Gist> >::const_iterator iter = gists.begin(); iter != gists.end(); iter++ ) {

#if 0 /* for now we do not initialize anything */
    /* collect initial gappy patterns */
    set<unsigned int> active_colors = (*iter)->get_colors();
    for ( set<unsigned int>::iterator color_iter = active_colors.begin(); color_iter != active_colors.end(); ++color_iter ) {
      _increment_pattern_count( ( (*iter)->get_color_pattern_from_color( *color_iter ) ).get() );
    }
#endif

  }

}

/* run one sampler iteration */
void TemplateSampler::iterate() {

  LOG(INFO) << "\t" << "Iteration # " << ++_iteration_number << " ...";

  /* Iterate over each training sample */
  for ( vector< tr1::shared_ptr<Gist> >::const_iterator iter = data.begin(); iter != data.end(); ++iter ) {

    /* Update model for the current data sample */
    (*iter)->sample_template();
    
  }

}

/* check whether the sampler has converged */
bool TemplateSampler::has_converged() {

  /* 1 - compute likelihood of current model */
  /* TODO */

  return false;

}

/* return iteration number */
unsigned int TemplateSampler::get_iteration_number() const {

  return _iteration_number;

}

/* dump sampler state */
void TemplateSampler::dump_state() {

  dump_state_sampler();
  dump_state_gists();

}

/* dump gists state */
void TemplateSampler::dump_state_gists() {

  string filename = "dump_gists." + boost::lexical_cast<std::string>( get_iteration_number() ) + ".out" ;
  ofstream gists_state_output( filename.c_str() );

  vector< tr1::shared_ptr<Gist> >::const_iterator iter = data.begin();
  
  while ( iter != data.end() ) {

    gists_state_output << (*iter)->as_string() << "\t" << (*iter)->get_category()->get_label() << endl;

    iter++;

  }

  gists_state_output.close();

}

/* dump sampler state */
void TemplateSampler::dump_state_sampler() {

  vector< GappyPatternProcess* > slot_types = _corpus.get_slot_types();
  vector< GappyPatternProcess* >::const_iterator iter = slot_types.begin();

  while ( iter != slot_types.end() ) {

    /* output file */
    unsigned int type_id = iter - slot_types.begin();
    string filename = "dump_state." + boost::lexical_cast<std::string>( get_iteration_number() ) + "." +
      boost::lexical_cast<std::string>( type_id ) + ".out" ;

    (*iter)->dump_state( filename );

    iter++;

  }

}

/* compute log likelihood */
double TemplateSampler::log_likelihood() const {

  double _log_likelihood = 0.0;

  for ( vector< tr1::shared_ptr<Gist> >::const_iterator iter = data.begin(); iter != data.end(); ++iter ) {

    /* compute likelihood for the current gist */
    _log_likelihood += log_likelihood( (*iter).get() );

  }

  return _log_likelihood;

}

/* compute log likelihood for a specific gist */
double TemplateSampler::log_likelihood( Gist* gist ) const {

  double _log_likelihood = 0.0;

  // P( w , c | params ) \prop P ( c | w , params )
  //  P( color combination ) * P
  // --> # of colors --> # 

  /* likelihood of individual color assignments */
  _log_likelihood = 0.0;

  return _log_likelihood;

}

/* sample slot word pattern */
void TemplateSampler::_sample_slot_word_pattern( Gist* gist , unsigned int index ) {

  /* 1 - get the slot object for the target location */
  tr1::shared_ptr<TemplateSlot> target_slot = gist->get_template()->get_slot_at_word_location( index );

  /* 2 - run the sampling procedure */
  target_slot->sample_color( index );

}
