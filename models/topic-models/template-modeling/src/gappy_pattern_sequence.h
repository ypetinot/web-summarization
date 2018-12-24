#ifndef __GAPPY_PATTERN_SEQUENCE_H__
#define __GAPPY_PATTERN_SEQUENCE_H__

#include "sequence.h"

/* extends the Sequence class with gappy pattern annotations */
class GappyPatternSequence: public TokenSequence {

 public:
  
  /* default constructor */
 GappyPatternSequence( const string& sequence_string ):TokenSequence(sequence_string) {
    // TODO : do we want to randomly initialize the gappy pattern annotations ?
  }
  
  /* constructor with pre-determined gappy pattern annotations */
 GappyPatternSequence( const string& sequence_string , const string& gappy_pattern_state ):TokenSequence(sequence_string) {
    set_gappy_pattern_state( gappy_pattern_state );
  }
  
  /* destructor */
  virtual ~GappyPatternSequence() {
    /* nothing for now */
  }

  void set_gappy_pattern_state( string gappy_pattern_state ) {
    /* TODO */
    assert(0);
  }

 protected:

  /* default constructor - only needed so GappyPatternSequences can be used with containers */
  GappyPatternSequence() {
    /* nothing */
  }
  
};

#endif
