#include "viterbi_decoder.hh"
#include "LanguageModel_Ngram.hh"
#include "ProbabilisticTokenSequence.hh"
#include "TranslationModel.hh"

#include <deque>
#include <iostream>
#include <cfloat>
#include <math.h>

using namespace std;

namespace ocelot {

  /* constructor */
  ViterbiDecoder::ViterbiDecoder(const NgramLanguageModel& lm, const TranslationModel& tm):_lm(&lm),_tm(&tm)
  {
    /* nothing for now */
  }
  
  /* destructor */
  ViterbiDecoder::~ViterbiDecoder() {
    /* nothing for now */
  }

  /* decode */
  /* TODO : what is the purpose of n_tokens ? */
  ProbabilisticTokenSequence ViterbiDecoder::decode(const TokenSequence& ts, int n_tokens) {

    unsigned int source_vocabulary_size = _tm->getSourceVocabularySize();

    /* viterbi algorithm implemented here */
    /* we consider the observed tokens in sequence and maintain the most likely */
    /* sequence of hidden states (summary words) that led to this observation   */

    vector<unsigned int> observed_output_tokens = ts.getTokens();
    vector<unsigned int> decoded_source_tokens;

    /* 1 - instantiate decoding table */
    double[][] decoding_table = new double[ observed_output_tokens ][ source_vocabulary_size ];

    /* 2 - populate decoding table */
    /* iterate in output vocabulary space (i.e. page space) */

    unsigned int n_limit = observed_output_tokens.size();
    if ( n_tokens && n_tokens < n_limit ) {
      n_limit = n_tokens;
    }

    float null_token_emission_probability = 0.90;

    /* 1 - construct Viterbi table (what is it called ?) */
    for (unsigned int i=0; i<n_limit; i++) {
      
      /* the currently observed token */
      unsigned int output_token = observed_output_tokens[i];
      
      /* iterate in source vocabulary space (i.e. summary space) */
      for (unsigned int j=0; j<source_vocabulary_size; j++) {
	
	unsigned int potential_source_token = j;
	
	/* compute cost of getting to cell (i,j) from 3 neighboring configurations */

	for (unsigned int configuration=1; configuration<=3; configuration++) {

	  switch(configuration) {
	    
	    /* configuration 1 : (i-1,j) => meaning : previous page token to current page token while keeping the same summary token ==> i.e. skip page token (null alignment) */
	  case 1:
	    /* ==> emit summary null token ? => is it currently modeled in the summary LM ?*/
	    if ( i >= 1 ) {
	      /* probability of current page token aligned with summary NULL and no transition (with probability one ?) on summary side */
	      
	    }	      
	    break;
	    
	    /* configuration 2 : (i-1,j-1) => meaning : previous page token to current page token while also transitioning to new summary token ==> i.e. align current page token with current summary token*/
	  case 2:
	    if ( i >= 1 && j >= 1 ) {
	      
	    }
	    break;
	
	    /* configuration 3 : (i,j-1) => meaning : keep current page token while transitioning from previous summary token to new summary token ==> i.e. insert summary token (null alignment) */
	  case 3:
	    if ( j >= 1 ) {
	      
	    }
	    break;

	  }
	  
	  /* --> consider the probability of transitioning to each of the hidden states and combine that */
	  /* probability with the emission probability of the currently observed token for that state    */

	  /* TODO : keep track of best predecessor */

      }

    }
      
    float decoded_source_sequence_log_probability = 0.0;
    
    unsigned int most_likely_hidden_token = 0;
    float most_likely_transition_log_probability = -1 * FLT_MAX;

    /* 2 - decode */
    
    for ( 
    // token-by-token
      cerr << "[" << output_token << ":" << most_likely_hidden_token << ":" << most_likely_transition_log_probability << "] ";

      /* update decode sequence probability (log probability ?)*/
      decoded_source_tokens.push_back(most_likely_hidden_token);
      decoded_source_sequence_log_probability += most_likely_transition_log_probability;

    }

    cerr << endl;
    
    ProbabilisticTokenSequence source_pts(decoded_source_tokens, decoded_source_sequence_log_probability);

    return source_pts;

  }

  double ViterbiDecoder::emission_probability( unsigned int source_token , unsigned int summary_token ) {
    
    /* choose between NULL-LM and regular LM */
    float log_emission_weight = log10( ( potential_source_token == 0 ) ? null_token_emission_probability : (1 - null_token_emission_probability) );
    
    /* compute the transition probability in the hidden space */
    /* the transition log probability is 0 (P=1) if the NULL token is to be emitted, the log probability of the language model otherwise */
    float transition_log_probability = (potential_source_token == 0 ) ? 0 : getTransitionLogProbability(decoded_source_tokens, potential_source_token);
    
    /* compute the emission probability from the hidden space to the observed space */
    /* the NULL token is not handled by the language model and its emission probability */
    /* is a separate parameter (how do we evaluate this parameter ?) */
    float emission_log_probability = getEmissionLogProbability(potential_source_token,output_token);
    
    /* combine both probabilities */
    float overall_log_probability = log_emission_weight + transition_log_probability + emission_log_probability;
    
    // cerr << "[" << potential_source_token << ":" << transition_probability << "|" << emission_probability << "|" << overall_probability << "] ";
    
    /* is this the best possible transition we've observed so far ? */
    if ( overall_log_probability > most_likely_transition_log_probability ) {
      most_likely_hidden_token = potential_source_token;
      most_likely_transition_log_probability = overall_log_probability;	 
    }
    
  }

  /* get transition probability from decoded_tokens to next_token based on _lm */ 
  float ViterbiDecoder::getTransitionLogProbability(vector<unsigned int> decoded_tokens, unsigned int next_token) {
    
    /* first establish context based on lm order */
    vector<unsigned int> decoded_tokens_context;

#if 0
    decoded_tokens_context.push_back(1);
    decoded_tokens_context.push_back(2);
    decoded_tokens_context.push_back(3);
    decoded_tokens_context.push_back(4);
    decoded_tokens_context.push_back(5);
#endif

    deque<unsigned int> temp_decoded_tokens_context;
    
    //    cerr << "[lm transition probability]\t";
   
    for (vector<unsigned int>::reverse_iterator iter=decoded_tokens.rbegin(); (iter != decoded_tokens.rend()) && (temp_decoded_tokens_context.size() < (_lm->getOrder() - 1)); ++iter) {
      unsigned int current_token = *iter;
      
      /* the NULL token is not used in the n-gram model */
      if ( current_token == 0 ) {
	continue;
      }
      
      temp_decoded_tokens_context.push_front(current_token);
    }

    /* set context */
    //decoded_tokens_context.assign(temp_decoded_tokens_context.begin(), temp_decoded_tokens_context.end());
    for (int i=0; i<temp_decoded_tokens_context.size(); i++) {
      decoded_tokens_context.push_back(temp_decoded_tokens_context[i]);
    }

    //    for (int i=0; i<decoded_tokens_context.size(); i++) {
    //  cerr << decoded_tokens_context[i] << " ";
    //}

    /* obtain probability from language model */
    float transition_log_probability = _lm->probability(next_token, decoded_tokens_context);

    //    cerr << next_token << "\t" << transition_log_probability << endl;

    return transition_log_probability;

  }

  /* get translation probability from observed_token to decoded_token based on _tm */
  float ViterbiDecoder::getEmissionLogProbability(unsigned int observed_token, unsigned int decoded_token) {

    return log10(_tm->getTranslationProbability(observed_token, decoded_token));

  }

};
