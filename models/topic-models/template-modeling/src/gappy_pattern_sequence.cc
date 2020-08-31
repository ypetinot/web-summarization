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
#endif
