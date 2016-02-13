#include "content_distribution.h"

/* default constructor - to be used for serialization purposes only */
ContentDistribution::ContentDistribution() {
  
  /* instance initialization */
  init();

}

/* constructor */
ContentDistribution::ContentDistribution(const string& smoothing_mode) {
  
  /* instance initialization */
  init();

}

/* destructor */
ContentDistribution::~ContentDistribution() {

  /* nothing */

}

/* merge in another content distribution */
void ContentDistribution::merge(const ContentDistribution& cd) {

  /* make sure the smoothing modes are compatible / the same */
  assert( ! _smoothing_mode.compare(cd._smoothing_mode) );
  
  /* update number of documents */
  _number_of_documents += cd._number_of_documents;
  
  /* update number of tokens */
  _number_of_tokens += cd._number_of_tokens;

  /* update token frequencies */
  vector<string> new_tokens = cd.get_tokens();
  for ( vector<string>::const_iterator iter = new_tokens.begin(); iter != new_tokens.end(); ++iter ) {
    
    string token = (*iter);

    /* update token frequencies */
    increment_token_frequency(token, cd.get_token_frequency(token));

    /* update document frequencies */
    increment_document_frequency(token, cd.get_document_frequency(token));

  }

}

/* get tokens with non-zero probabilities */
vector<string> ContentDistribution::get_tokens() const {

  vector<string> tokens;

  for ( google::sparse_hash_map<string,unsigned>::const_iterator iter = _token_to_frequency.begin(); iter != _token_to_frequency.end(); ++iter ) {
    tokens.push_back((*iter).first);
  }

  return tokens;

}

/* get token probability */
float ContentDistribution::get_probability(string token) {

  unsigned tf = get_token_frequency(token);
  
  return ( tf / _number_of_tokens );

}

/* get token frequency */
unsigned ContentDistribution::get_token_frequency(string token) const {

  google::sparse_hash_map<string,unsigned>::const_iterator iter = _token_to_frequency.find(token);
  if ( iter == _token_to_frequency.end() ) {
    return 0;
  }

  return (*iter).second;

}

/* get document frequency */
unsigned ContentDistribution::get_document_frequency(string token) const {

  google::sparse_hash_map<string,unsigned>::const_iterator iter = _token_to_document_frequency.find(token);
  if ( iter == _token_to_document_frequency.end() ) {
    return 0;
  }

  return (*iter).second;

}

/* intialization code */
void ContentDistribution::init() {

  /* nothing for now */

}

/* update token frequency info */
void ContentDistribution::increment_token_frequency(string token, unsigned count) {

  /* update token count */
  google::sparse_hash_map<string,unsigned>::iterator iter = _token_to_frequency.find(token);
  if ( iter == _token_to_frequency.end() ) {
    _token_to_frequency[token] = 0;
  }
  _token_to_frequency[token] += count;

}

/* update document frequency info */
void ContentDistribution::increment_document_frequency(string token, unsigned count) {

  /* update document count */
  google::sparse_hash_map<string,unsigned>::iterator iter = _token_to_document_frequency.find(token);
  if ( iter == _token_to_document_frequency.end() ) {
    _token_to_document_frequency[token] = 0;
  }
  _token_to_document_frequency[token] += count;

}  

/* set document frequency */
void ContentDistribution::set_document_frequency(string token, unsigned count) {

  /* set document count to 1 for this token */
  _token_to_document_frequency[token] = count;
  
}
