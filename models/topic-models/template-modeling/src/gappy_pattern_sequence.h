#ifndef __GAPPY_PATTERN_SEQUENCE_H__
#define __GAPPY_PATTERN_SEQUENCE_H__

#include "sequence.h"

/* sequence fully annotated with a collection of gappy patterns as described in \cite{Gimpel2011} */
/* extends the Sequence class with gappy pattern annotations */
class GappyPatternSequence: public Sequence {

 public:
  
  /* constructor with pre-determined gappy pattern annotations */
  GappyPatternSequence( const string& sequence_string , const vector<unsigned int>& gappy_pattern_sequence_coloring ):
   Sequence(sequence_string) {
    assert( gappy_pattern_sequence_coloring.size() == length() );
    set_gappy_pattern_state( gappy_pattern_sequence_coloring );
  }

  /* constructor given a raw input sequence */
  GappyPatternSequence( const string& sequence_string ):
    Sequence(sequence_string) {
    set_gappy_pattern_state(_random_coloring(length()));
  }
  
  /* default constructor - only needed so GappyPatternSequences can be used with containers */
  GappyPatternSequence() {
    /* nothing */
  }
  
  /* destructor */
  virtual ~GappyPatternSequence() {
    /* nothing for now */
  }

 protected:

  /* coloring */
  vector<unsigned int> _coloring;

 #if 0
  /* colors */
  vector<GappyPattern> _colors;
 #endif

  void set_gappy_pattern_state( vector<unsigned int> gappy_pattern_state ) {
    _coloring = gappy_pattern_state;
    /* TODO : should the corresponding list of GappyPatterns be pre-generated or generated on-the-fly ? */
  }

  /* generates random coloring string given target sequence length */
  /* TODO : should follow the coloring constraints given in \cite{Gimpel2011} */ 
  vector<unsigned int> _random_coloring(unsigned int sequence_length) {
    vector<unsigned int> coloring(sequence_length);
    /* steps 2-3 from \cite{Gimpel2011} p2/11 */
    /* sample the number of colors in the sentence given its length */
    unsigned int m = Uniform(1,sequence_length);
    do {
      unsigned int m_effective = 0;
      vector<unsigned int> color_coverage(m,1);
      /* for each word index i sample the color of word i */
      for (unsigned int i=0; i<sequence_length; ++i) {
	unsigned int c_i = Uniform(1,m);
	m_effective += color_coverage[c_i];
	color_coverage[c_i] = 0;
	coloring[i] = c_i;
      }
    } while (m_effective != m);
    return coloring;
  }
     
};

#endif
