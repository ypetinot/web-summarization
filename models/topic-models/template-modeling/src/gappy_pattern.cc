#include "gappy_pattern.h"
#include "gist.h"
#include "parameters.h"
#include "statistics.h"
#include "template_slot.h"

#include <boost/lexical_cast.hpp>
#include <glog/logging.h>
#include <fstream>

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

/* constructor */
GappyPattern::GappyPattern( const TemplateSlot& ts )
  :PoissonProbabilisticObject(ts.get_gist()->get_corpus(),FLAGS_gappy_patterns_lambda),TemplateElement(ts.get_gist(),ts.get_from(),ts.get_to()),_gp_location(ts),number_of_words(0),_pattern_markers( ts.length() , 0 ) {

  /* nothing for now */

}

/* destructor */
GappyPattern::~GappyPattern() {

  /* nothing for now */

}

/* add word to pattern */
const GappyPattern& GappyPattern::add_word( unsigned int index ) {

  set_pattern_marker( index , true );

  number_of_words++;

  return *this;

}

/* remove word from pattern */
const GappyPattern& GappyPattern::remove_word( unsigned int index ) {

  set_pattern_marker( index , false );

  number_of_words--;

  return *this;

}

/* set pattern marker */
void GappyPattern::set_pattern_marker( unsigned int index , bool status ) {

  unsigned int offset = _gp_location.get_from();

  CHECK_GE( index , 0 );
  CHECK_LE( index - offset , _pattern_markers.size() );

  _pattern_markers[ index - offset ] = status;

}

/* add gap to pattern */
const GappyPattern& GappyPattern::add_gap( unsigned int index ) {

  return remove_word( index );

}

/* number of words getter */
unsigned int GappyPattern::get_number_of_words() const {

  return number_of_words;

}

/* compute the probability of this object */
double GappyPattern::log_probability() {

  vector<long> unigrams = get_words();
  unsigned int number_of_arrangements = get_number_of_arrangements();

  double log_probability = _base_log_probability( get_number_of_words() , unigrams , number_of_arrangements );
  
  /* the log probability cannot be 0 ? */
  CHECK( log_probability );

  return log_probability;


}

double GappyPattern::_base_log_probability( unsigned int number_of_words , const vector<long>& unigrams , unsigned int number_of_gap_arrangements ) {

  /* 1 - poisson distribution */
  double base_probability = get_poisson_log_probability( number_of_words );

  /* 2 - unigram distribution */
  base_probability += log( compute_unigram_probability( unigrams ) );

  /* 3 - gap/word arrangement distribution */
  //base_probability += log( _compute_gappy_pattern_arrangement_probability( gappy_pattern ) );

  return base_probability;

}

/* get words */
vector<long> GappyPattern::get_words() const {

  vector<long> result;
  for ( vector<unsigned short int>::const_iterator iter = _pattern_markers.begin(); iter != _pattern_markers.end(); iter++ ) {
    
    if ( *iter ) {
      result.push_back( _gp_location.get_word( iter - _pattern_markers.begin() ) );
    }
    
  }
  
  return result;

}

/* get pattern as a string */
string GappyPattern::as_string() const {
  return _as_string();
}

/* get pattern as a string (log content) */
string GappyPattern::as_string_log() const {
  return _as_string();
}

/* get pattern as a string with many options */
string GappyPattern::_as_string() const {

  bool do_append = false;
  bool prev_was_gap = false;

  string pattern;
  string component;

  for ( vector<unsigned short int>::const_iterator iter = _pattern_markers.begin(); iter != _pattern_markers.end(); ++iter ) {
    
    if ( *iter != 0 ) {
     
      unsigned int i = iter - _pattern_markers.begin();

      do_append = true;
      long word_id = get_word( i );

      if ( word_id == WORD_ID_BOG ) {
	component = WORD_STRING_BOG;
      }
      else if ( word_id == WORD_ID_EOG ) {
	component = WORD_STRING_EOG;
      }
      else {
	component = _gp_location.get_word_as_string( i );
      }

      prev_was_gap = false;
 
    }
    else {

      if ( !prev_was_gap ) {
	do_append = true;
	component = "_";
	prev_was_gap = true;
      }

    }

    if ( do_append ) {

      if ( iter != _pattern_markers.begin() ) {
	pattern.append( " " );
      }
      
      pattern.append( component );

    }

    do_append = false;

  }

  return pattern;
  
}

#if 0
/* insert word at the specified location */
const GappyPattern& GappyPattern::insert_word( unsigned int i ) {

  /* TODO */
  CHECK(0);

  return *this;

}
#endif

/* return the status of the word at the specified index */
const bool GappyPattern::get_pattern_marker( unsigned int i ) const {

  unsigned int target_location = i - _gp_location.get_from();
  CHECK( _valid_index( target_location ) );

  return ( _pattern_markers.at( target_location ) != 0 );
  
}

/* check index validity */
bool GappyPattern::_valid_index( unsigned int index ) const {

  /* TODO: can we do better ? */
  if ( index < 0 || index > _pattern_markers.size() ) {
    return false;
  }

  return true;

}

/* get number of arrangements */
long GappyPattern::get_number_of_arrangements() const {

  /* TODO */
  return 1;

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

  return _gappy_pattern_dp.new_probability( pattern );

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
