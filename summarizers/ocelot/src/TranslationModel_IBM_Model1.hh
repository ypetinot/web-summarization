#ifndef __TRANSLATION_MODEL_IBM_Model1__
#define __TRANSLATION_MODEL_IBM_Model1__

#include <string>

#include "TranslationModel.hh"

/* use Giza++ API */
#include "model1.h"

using namespace std;

namespace IBM {
  
   namespace Model1 {
     
     class TranslationModel: public ::TranslationModel {

     private:

       /* source vocabulary */
       vcbList _source_vocabulary;
       
       /* output vocabulary */
       vcbList _output_vocabulary;

       /* underlying tmodel */
       tmodel<float,float> _model1_table;

       /* constructor */
       TranslationModel();
       
     public:

       /* destructor */
       ~TranslationModel();

       /* factory method to load a particular language model */
       static TranslationModel* loadTranslationModel(string tm_name, string source_vocab_filename, string output_vocab_filename);

       /* get the translation probability between a source token and an output token */
       virtual float getTranslationProbability(unsigned int source_token, unsigned int output_token) const;

       /* get the source vocabulary size */
       unsigned int getSourceVocabularySize() const;
       
       /* get the output vocabulary size */
       unsigned int getOutputVocabularySize() const;

     };

   };

};

#endif
