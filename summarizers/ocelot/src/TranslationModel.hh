#ifndef __TRANSLATION_MODEL__
#define __TRANSLATION_MODEL__

#include <string>

using namespace std;

class TranslationModel {
  
public:

  /* factory method to load a particular language model */
  static TranslationModel* loadTranslationModel(string tm_name);
  
  /* get the translation probability between a source token and an output token */
  virtual float getTranslationProbability(unsigned int source_token, unsigned int output_token) const = 0;

  /* get the source vocabulary size */
  virtual unsigned int getSourceVocabularySize() const = 0;

  /* get the output vocabulary size */
  virtual unsigned int getOutputVocabularySize() const = 0;

};

#endif
