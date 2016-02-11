#include "LanguageModel_SRILM.hh"

#include <LMClient.h>
#include <Ngram.h>

namespace SRI {

  /* constructor */
  LanguageModel::LanguageModel(unsigned int order)
    : NgramLanguageModel(order), lm_vocab(NULL), lm(NULL), lm_client(NULL) {
    /* nothing for now */
  }
  
  /* destructor */
  LanguageModel::~LanguageModel() {
    /* nothing for now */
  }
  
  /* lookup probability of the specified token */
  double LanguageModel::probability(unsigned int token, vector<unsigned int> context) const {

    unsigned int srilm_offset = 3;

    VocabIndex vi_token = token + srilm_offset;

    VocabIndex vi_context[context.size() + 1];
    for (unsigned int i=0; i<context.size(); i++) {
      vi_context[i] = context[i] + srilm_offset;
    }
    vi_context[context.size()] = Vocab_None;

    return ( lm_client->wordProb(vi_token, &vi_context[0]) / log10(exp(1.0)) );
  }
    
  /* factory method to load a particular language model */
  LanguageModel* LanguageModel::loadLanguageModel(string lm_info, string vocabulary_file, unsigned int order, bool use_server_mode) {
    
    /* create new LanguageModel instance */
    LanguageModel* sri_lm = new LanguageModel(order);

    /* vocabury file */
    File vocab_file(vocabulary_file.c_str(), "r");

    /* instantiate underlying vocabulary object */
    /* shouldn't be needed since we're going to work directly with word ids, but just in case */
    sri_lm->lm_vocab = new Vocab();
    sri_lm->lm_vocab->read(vocab_file);
    sri_lm->lm_vocab->unkIsWord() = true;
    sri_lm->lm_vocab->toLower() = true;

    /* instantiate underlying lm client */
    if ( use_server_mode ) {
      sri_lm->lm_client = new LMClient(*(sri_lm->lm_vocab), use_server_mode?lm_info.c_str():NULL, order, order);
    }
    else {
      sri_lm->lm_client = new Ngram(*(sri_lm->lm_vocab), order);
      File lm_file(lm_info.c_str(), "r");
      sri_lm->lm_client->read(lm_file,0);
      // sri_lm->lm_client->running(true);
    }

    return sri_lm;

  }

};
