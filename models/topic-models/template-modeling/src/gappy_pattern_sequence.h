#ifndef __GAPPY_PATTERN_SEQUENCE_H__
#define __GAPPY_PATTERN_SEQUENCE_H__

#include "sampler.h"
#include "sequence.h"

/* sequence fully annotated with a collection of gappy patterns as described in \cite{Gimpel2011} */
/* extends the Sequence class with gappy pattern annotations */
class GappyPatternSequence: public Sequence, public Sampler
//, public ProbabilisticObject
{

 public:
  
  /* constructor with pre-determined gappy pattern annotations */
  GappyPatternSequence( const unsigned int random_seed , const string& sequence_string , const vector<unsigned int>& gappy_pattern_sequence_coloring ):
    Sequence(sequence_string),Sampler(random_seed) {
    assert( gappy_pattern_sequence_coloring.size() == length() );
    set_gappy_pattern_state( gappy_pattern_sequence_coloring );
  }

  /* constructor given a random seed and a raw input sequence */
  GappyPatternSequence( const unsigned int random_seed , const string& sequence_string ):
    Sampler(random_seed),
    GappyPatternSequence(sequence_string,set_gappy_pattern_state(_random_coloring(length()))) {
    /* nothing */
  }
  
  /* constructor given a raw input sequence */
  GappyPatternSequence( const string& sequence_string ):
    GappyPatternSequence( DEFAULT_RANDOM_SEED , sequence_string ) {
    /* nothing */
  }
  
  /* default constructor - only needed so GappyPatternSequences can be used with containers */
  GappyPatternSequence() {
    /* nothing */
  }
  
  /* destructor */
  virtual ~GappyPatternSequence() {
    /* nothing for now */
  }

  /* string version of this object */
  string as_string() const {
    /* return string representing the  original sequence annotated with the coloring of the individual tokens */
    ostringstream oss;
    /* TODO : reimplement using an iterator */
    unsigned int sequence_length = length();
    /* TODO : is there a better place to enforce this constraint ? */
    assert(sequence_length == _coloring.size());
    for (unsigned int i=0; i<sequence_length; ++i) {
      oss << get_token_as_string(i) << " [" << _coloring[i] << "]";
    }
    return oss.str();
  }

#if 0
  /* compute the log probability of this object */
  double log_probability() {
    
  }
#endif
  
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
  vector<unsigned int> _random_coloring(const unsigned int sequence_length) {
    vector<unsigned int> coloring(sequence_length);
    /* steps 2-3 from \cite{Gimpel2011} p2/11 */
    /* sample the number of colors in the sentence given its length */
    unsigned int m = sample_integer_uniform(1,sequence_length);
    unsigned int m_effective;
    do {
      unsigned int m_effective;
      vector<unsigned int> color_coverage(m,1);
      /* for each word index i sample the color of word i */
      for (unsigned int i=0; i<sequence_length; ++i) {
	unsigned int c_i = sample_integer_uniform(1,m);
	m_effective += color_coverage[c_i];
	color_coverage[c_i] = 0;
	coloring[i] = c_i;
      }
    } while (m_effective != m);
    return coloring;
  }
     
};

#endif
