#include "gappy_pattern.h"
#include "gist.h"
#include "parameters.h"
#include "statistics.h"
#include "template_slot.h"

#include <glog/logging.h>
#include <fstream>

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
