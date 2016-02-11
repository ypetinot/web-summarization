#ifndef __VITERBI_DECODER__
#define __VITERBI_DECODER__

#include <vector>

using namespace std;

class NgramLanguageModel;
class TokenSequence;
class ProbabilisticTokenSequence;
class TranslationModel;

namespace ocelot {

  class ViterbiDecoder {
    
  public:
    
    /* constructor */
    ViterbiDecoder(const NgramLanguageModel& lm, const TranslationModel& tm);
    
    /* destructor */
    ~ViterbiDecoder();

    /* decode */
    ProbabilisticTokenSequence decode(const TokenSequence& ts, int n_tokens);
    
  private:
    
    /* underlying language model */
    const NgramLanguageModel* const _lm;
    
    /* underlying translation model */
    const TranslationModel* const _tm;
    
    /* get transition probability from decoded_tokens to next_token based on _lm */ 
    float getTransitionLogProbability(vector<unsigned int> decoded_tokens, unsigned int next_token);

    /* get translation probability from observed_token to decoded_token based on _tm */
    float getEmissionLogProbability(unsigned int observed_token, unsigned int decoded_token);
    
  };

};

#endif
