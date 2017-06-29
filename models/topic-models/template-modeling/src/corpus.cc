#include "corpus.h"
#include "gist.h"

#include <set>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include "strutil.h"

using namespace google::protobuf;

/* constructor */
Corpus::Corpus( double template_poisson_lambda , double template_dp_alpha , double slot_type_dp_alpha, double gappy_pattern_poisson_lambda , double alpha )
  :
#if 0
_template_base_distribution(*this,template_poisson_lambda),_slot_type_base_distribution(*this),
#endif
_template_dp("templates",template_dp_alpha),_slot_type_dp("slot-types",slot_type_dp_alpha),
_gappy_patterns_lambda(gappy_pattern_poisson_lambda),_gappy_patterns_alpha(alpha),
   _total_unigram_count(0),
   _next_slot_type_id(0) {
  
  /* init unigram --> counts */
  _unigram_counts.set_empty_key(UNIGRAMS_EMPTY_KEY);
  _unigram_counts.set_deleted_key(UNIGRAMS_DELETED_KEY);

}

/* register word instance */
void Corpus::register_word_instance( const Gist* gist , long word_id ) {

  _unigram_counts[ word_id ]++;
  _total_unigram_count++;

}

/* load gist data */
vector< tr1::shared_ptr<Gist> > Corpus::load_gist_data(const string& filename) {

  ifstream input_file(filename.c_str());
  CHECK(input_file.is_open());

  vector< tr1::shared_ptr<Gist> > gists;

  string current_line;
  while( true ) {

    getline(input_file, current_line);

    if ( input_file.eof() ) {
      break;
    }

    vector<string> tokens;
    current_line = StringReplace(current_line, "\n", "", true);

    SplitStringUsing(current_line, "\t", &tokens);
    CHECK_GE(tokens.size(), 2);
    CHECK_LE(tokens.size(), 3);
    
    if ( tokens.size() != 3 ) {
      LOG(INFO) << "Skipping invalid entry: " << current_line;
      continue;
    }

    /* line format: <url> \t <word-id-sequence> \t <category> */
    string url = tokens[0];
    vector<string> words;
    SplitStringUsing(tokens[1], " ", &words);

    vector<long> word_ids;
    word_ids.push_back( WORD_ID_BOG ); /* add bog node */
    for (vector<string>::iterator it = words.begin() ; it != words.end(); ++it) {
      word_ids.push_back( atol( (*it).c_str() ) );
    }
    word_ids.push_back( WORD_ID_EOG ); /* add eog node */

    string path = tokens[2];

    /* Map path to actual Category instance */
    /* TODO ! */
    //Category* category = TreeManager ...
    tr1::shared_ptr<Category> category( new Category( path ) );

    tr1::shared_ptr<Gist> gist( new Gist( *this , url , word_ids , category ) );
    gists.push_back( gist );

    /* collect word frequency data */
    unsigned number_of_words = gist.get()->length();
    for ( unsigned int i = 0; i < number_of_words; i++ ) {
      unsigned int word = gist.get()->get_word( i );
      register_word_instance( gist.get() , word );
    }

  }

  return gists;

}

/* get total unigram count */
long Corpus::get_total_unigram_count() const {
  return _total_unigram_count;
}

/* get unigram count */
long Corpus::get_unigram_count( long word_id ) const {

  dense_hash_map<unsigned int, long>::const_iterator unigram_iter = _unigram_counts.find( word_id );
  if ( unigram_iter != _unigram_counts.end() ) {
    return (*unigram_iter).second;
  }

  return 0;

}

/* get next slot type id */
unsigned int Corpus::get_next_slot_type_id() {

  return _next_slot_type_id++;

}

/* get slot types */
vector< GappyPatternProcess* > Corpus::get_slot_types() {

#if 0
  vector< string > instance_ids = _slot_type_dp.get_instance_ids();
  
  /* the slot ids are simply indices in  ... */
#endif

  if ( (!_slot_types.size()) || (_slot_types[ _slot_types.size() - 1 ]->count() > 0) ) {

    /* create "new" slot type for sampling purposes */
    /* Note: is this the right place for this ? */
    
    tr1::shared_ptr<GappyPatternProcess> new_process( new GappyPatternProcess( _slot_types.size() , *this ) );
    _slot_types.push_back( new_process );

  }

  vector< GappyPatternProcess* > slot_types;
  for ( vector< tr1::shared_ptr<GappyPatternProcess> >::const_iterator iter = _slot_types.begin(); iter != _slot_types.end(); ++iter ) {
    slot_types.push_back( (*iter).get() );
  }

  return slot_types;

}
