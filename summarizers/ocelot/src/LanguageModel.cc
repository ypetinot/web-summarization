#include "LanguageModel.hh"

/* note that this layer operates at the word id level and that the actual word strings are never seen */
/* this allows to keep the language modeling/statistical processing as simple and effective as        */
/* possible                                                                                           */
  
/* destructor */
LanguageModel::~LanguageModel() {
  /* nothing for now */
}

/* factory method to load a particular language model */
LanguageModel* LanguageModel::loadLanguageModel(string lm_name) {
    
  /* uses configuration parameters to load the requested language model */
  
  return NULL;
  
}

