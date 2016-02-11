#ifndef __LANGUAGE_MODEL__
#define __LANGUAGE_MODEL__

#include <string>
#include <vector>

using namespace std;

class LanguageModel {
  
public:
    
  /* destructor */
  virtual ~LanguageModel();
    
  /* lookup probability of the specified token */
  virtual double probability(unsigned int token, vector<unsigned int> context) const = 0;
  
  /* factory method to load a particular language model */
  static LanguageModel* loadLanguageModel(string lm_name);
  
};  

#endif
