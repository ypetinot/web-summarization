#ifndef __GAPPY_PATTERN_SEQUENCE_H__
#define __GAPPY_PATTERN_SEQUENCE_H__

#include "sequence.h"

/* abstracts the notion of a standalone sequence fully annotated with one or more gappy patterns */
/* extends the Sequence class with gappy pattern annotations */
class GappyPatternSequence: public TemplaticSequence {

 public:
  
  /* constructor given a raw input sequence */
 GappyPatternSequence( const string& sequence_string ):TemplaticSequence(sequence_string) {
    // TODO : do we want to randomly initialize the gappy pattern annotations ?
  }
  
  /* constructor with pre-determined gappy pattern annotations */
 GappyPatternSequence( const string& sequence_string , const string& gappy_pattern_state ):TemplaticSequence(sequence_string) {
    set_gappy_pattern_state( gappy_pattern_state );
  }

  // TODO : reintroduce if needed
  ///* default constructor - only needed so GappyPatternSequences can be used with containers */
  ///* TODO : make this method protected */
  //GappyPatternSequence() {
  //  /* nothing */
  //}
  
  /* destructor */
  virtual ~GappyPatternSequence() {
    /* nothing for now */
  }

  void set_gappy_pattern_state( string gappy_pattern_state ) {
    /* TODO */
    assert(0);
  }

 protected:
  
};

#endif
