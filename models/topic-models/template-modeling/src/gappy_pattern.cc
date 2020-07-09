#include "gappy_pattern.h"
#include "parameters.h"
#include "statistics.h"

#include <glog/logging.h>
#include <fstream>

/* constructor */
GappyPattern::GappyPattern(unsigned int length)
  :number_of_words(0),_pattern_markers( length , 0 ) {
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
  CHECK_GE( index , 0 );
  CHECK_LE( index , _pattern_markers.size() );
  _pattern_markers[ index ] = status;
}

/* add gap to pattern */
const GappyPattern& GappyPattern::add_gap( unsigned int index ) {
  return remove_word( index );
}

/* number of words getter */
unsigned int GappyPattern::get_number_of_words() const {
  return number_of_words;
}

/* get pattern as a string */
string GappyPattern::as_string() const {
  return _as_string();
}

/* get pattern as a string (log content) */
string GappyPattern::as_string_log() const {
  return _as_string();
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

  CHECK( _valid_index( i ) );

  return ( _pattern_markers.at( i ) != 0 );
  
}

/* check index validity */
bool GappyPattern::_valid_index( unsigned int index ) const {

  /* TODO: can we do better ? */
  if ( index < 0 || index > _pattern_markers.size() ) {
    return false;
  }

  return true;

}
