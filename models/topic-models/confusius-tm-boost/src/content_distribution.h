#ifndef __CONTENT_DISTRIBUTION__
#define __CONTENT_DISTRIBUTION__

#include "serialization.h"

#include <string>
#include <vector>

#include <google/sparse_hash_map>

using namespace std;

class ContentDistribution {

 public:

  /* default constructor - to be used for serialization purposes only */
  ContentDistribution();

  /* constructor */
  ContentDistribution(const string& smoothing_mode);

  /* destructor */
  virtual ~ContentDistribution();

  /* merge in another content distribution */
  void merge(const ContentDistribution& cd);

  /* get tokens with non-zero probabilities */
  vector<string> get_tokens() const;

  /* get token probability */
  float get_probability(string token);

  /* get token frequency */
  unsigned get_token_frequency(string token) const;

  /* get document frequency */
  unsigned get_document_frequency(string token) const;

 protected:

  /* token frequency (tf) */
  google::sparse_hash_map<string,unsigned> _token_to_frequency;

  /* document frequency (df) */
  google::sparse_hash_map<string,unsigned> _token_to_document_frequency;

  /* total number of documents */
  unsigned _number_of_documents;

  /* total number of tokens */
  unsigned _number_of_tokens;

  /* smoothing mode */
  string _smoothing_mode;

  /* update token frequency */
  void increment_token_frequency(string token, unsigned count);
  
  /* update document frequency */
  void increment_document_frequency(string token, unsigned count);  

  /* set document frequency */
  void set_document_frequency(string token, unsigned count);

 private:

  /* intialization code */
  void init();

  friend class boost::serialization::access;
  template<class Archive>
    void serialize(Archive & ar, const unsigned int version)
    {
      ar & boost::serialization::make_nvp("_token_to_frequency", _token_to_frequency);
      ar & boost::serialization::make_nvp("_token_to_document_frequency", _token_to_document_frequency);
      ar & boost::serialization::make_nvp("_number_of_tokens", _number_of_tokens);
      ar & boost::serialization::make_nvp("_number_of_documents", _number_of_documents);
      ar & boost::serialization::make_nvp("_smoothing_mode", _smoothing_mode);
    }
  
};

#endif
