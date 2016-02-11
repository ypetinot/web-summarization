#include "LanguageModel_Ngram.hh"

/* constructor */
NgramLanguageModel::NgramLanguageModel(unsigned int order)
  :_order(order) {
  /* nothing for now */
}

/* destructor */
NgramLanguageModel::~NgramLanguageModel() {
  /* nothing for now */
}

/* return the order of this Ngram language model */
unsigned int NgramLanguageModel::getOrder() const {
  return _order;
}
