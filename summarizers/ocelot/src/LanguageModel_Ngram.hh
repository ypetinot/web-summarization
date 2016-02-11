#ifndef __LANGUAGE_MODEL_NGRAM__
#define __LANGUAGE_MODEL_NGRAM__

#include <string>
#include <vector>

#include "LanguageModel.hh"

using namespace std;

class NgramLanguageModel: public LanguageModel {
  
private:

  /* order */
  unsigned int _order;

public:
    
  /* constructor */
  NgramLanguageModel(unsigned int order);

  /* destructor */
  virtual ~NgramLanguageModel();
    
  /* lookup probability of the specified token */
  virtual double probability(unsigned int token, vector<unsigned int> context) const = 0;
  
  /* return the order of this Ngram language model */
  unsigned int getOrder() const;
  
};  

#endif
