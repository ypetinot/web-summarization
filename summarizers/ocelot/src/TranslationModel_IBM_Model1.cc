#include "TranslationModel_IBM_Model1.hh"

#include "giza-pp/Parameter.h"
#include "giza-pp/Globals.h"
#include "giza-pp/vocab.h"

/* will not compile otherwise */
GLOBAL_PARAMETER(float, PROB_SMOOTH,"probSmooth","probability smoothing (floor) value ",PARLEV_OPTHEUR,1e-7);

namespace IBM {
  
   namespace Model1 {

     /* constructor */
     TranslationModel::TranslationModel()
       : _model1_table() {
       /* nothing for now */
     }
       
     /* destructor */
     TranslationModel::~TranslationModel() {
       /* nothing for now */
     }

     /* factory method to load a particular language model */
     TranslationModel* TranslationModel::loadTranslationModel(string tm_name, string source_vocab_filename, string output_vocab_filename) {

       /* create new instance of TranslationModel */
       TranslationModel* tm = new TranslationModel();

       /* set source vocabulary */
       tm->_source_vocabulary = vcbList(source_vocab_filename.c_str());
       tm->_source_vocabulary.readVocabList();

       /* set output vocabulary */
       tm->_output_vocabulary = vcbList(output_vocab_filename.c_str());
       tm->_output_vocabulary.readVocabList();

       /* load translation table */
       tm->_model1_table.readProbTable(tm_name.c_str());

       return tm;

     }

     /* get the translation probability between a source token and an output token */
     float TranslationModel::getTranslationProbability(unsigned int source_token, unsigned int output_token) const {
       return _model1_table.getProb(source_token, output_token);
     }

     /* get the source vocabulary size */
     unsigned int TranslationModel::getSourceVocabularySize() const {
       return _source_vocabulary.uniqTokens();
     }
     
     /* get the output vocabulary size */
     unsigned int TranslationModel::getOutputVocabularySize() const {
       return _output_vocabulary.uniqTokens();
     }

   };

};

