#ifndef __LANGUAGE_MODEL_SRILM__
#define __LANGUAGE_MODEL_SRILM__

#include <string>
#include <vector>

#include "LanguageModel_Ngram.hh"

/* this class is implemented based on the SRILM API */
#include <LM.h>
#include <Vocab.h>

using namespace std;

namespace SRI {

  class LanguageModel: public ::NgramLanguageModel {
    
    /* underlying vocab object (SRILM) */
    Vocab* lm_vocab;

    /* underlying language model (SRILM) */
    LM* lm;

    /* underlying lm client (SRILM) */
    LM* lm_client;
    
  public:
    
    /* constructor */
    LanguageModel(unsigned int order);

    /* destructor */
    virtual ~LanguageModel();
    
    /* lookup probability of the specified token */
    virtual double probability(unsigned int token, vector<unsigned int> context) const;
    
    /* factory method to load a particular language model */
    static LanguageModel* loadLanguageModel(string lm_load_info, string vocabulary_file, unsigned int order, bool use_server_mode);
    
  };
  
};

#endif
