#include "gappy_pattern_sequence.h"

#if 0
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
#endif
