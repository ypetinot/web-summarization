#include "gappy_pattern_process.h"

#include <boost/lexical_cast.hpp>

/* constructor */
GappyPatternProcess::GappyPatternProcess( unsigned int id , Corpus& corpus )
  :_id(id),_corpus(corpus),_gappy_pattern_dp(as_string(),FLAGS_gappy_patterns_dp_alpha) {

  /* init gappy pattern counts */
  m_gappy_pattern_counts.set_empty_key("__GAPPY_PATTERN_PROCESS_EMPTY_KEY__");
  m_gappy_pattern_counts.set_deleted_key("__GAPPY_PATTERN_PROCESS_DELETED_KEY__");

}

/* Increments count for the target gappy pattern */
unsigned int GappyPatternProcess::_increment_pattern_count( const GappyPattern& gappy_pattern ) {

  return _gappy_pattern_dp.add_instance( gappy_pattern );

}

/* Decrements count for the target gappy pattern */
unsigned int GappyPatternProcess::_decrement_pattern_count( const GappyPattern& gappy_pattern ) {

  return _gappy_pattern_dp.remove_instance( gappy_pattern );
  
}

/* dump process state */
void GappyPatternProcess::dump_state( string filename ) {

  ofstream state_output( filename.c_str() );
  
  dense_hash_map<string, unsigned int, MurmurHash2, eqstring>::iterator iter = m_gappy_pattern_counts.begin();
  
  while ( iter != m_gappy_pattern_counts.end() ) {
    
    string pattern = (*iter).first;
    unsigned int pattern_count = (*iter).second;
    
    state_output << pattern << "\t" << pattern_count << endl;
    
    iter++;
    
  }
  
  state_output.close();

}

/* compute the probability of a gappy pattern */
double GappyPatternProcess::_compute_probability_gappy_pattern_update( GappyPattern& gp , unsigned int candidate_location ) {

  GappyPattern gp_to( gp );

  /* insert current word in this pattern at the relevant location */
  CHECK( ! gp_to.get_pattern_marker( candidate_location ) );
  gp_to.add_word( candidate_location );
  CHECK( gp_to.get_pattern_marker( candidate_location ) );
  
  double update_probability = _gappy_pattern_dp.transition_probability( gp , gp_to );

  return update_probability;

}

/* compute probability of gap/unigram arrangement in gappy pattern */
double GappyPatternProcess::_compute_gappy_pattern_arrangement_probability( const GappyPattern* gappy_pattern ) const {

  double probability = 1.0;

  return probability;

}

/* compute probability of introducing a new color for the target word */
double GappyPatternProcess::_probability_new_color( GappyPattern& pattern ) {

  return _gappy_pattern_dp.multinomial_probability( pattern );

}

/* string version of this object */
string GappyPatternProcess::as_string() const {

  /* we simply return a unique id for this process */  
  return "gp-" + boost::lexical_cast<std::string>( _id );

}

/* string version of this object (log content) */
string GappyPatternProcess::as_string_log() const {

  return as_string();

}

/* get occurence count */
long GappyPatternProcess::count() const {

  return _gappy_pattern_dp.get_total_instances();

}

/* log probability */
double GappyPatternProcess::log_probability() {

#if 0
  double instance_count = _corpus.get_slot_type_dp().get_instance_count( *this );
  double total_instance_count = _corpus.get_slot_type_dp().get_total_instances();

  return ( instance_count / total_instance_count );
#endif

  /* Only one "type" pf GP processes --> 1 */
  return 0;

}
