#include "corpus.h"
#include "definitions.h"
#include "gist.h"

#include <set>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include "strutil.h"

using namespace google::protobuf;

/* constructor */
Corpus::Corpus()
#if 0
_template_base_distribution(*this,template_poisson_lambda),_slot_type_base_distribution(*this),
#endif
{
  
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

    tr1::shared_ptr<Gist> gist( new Gist( url , word_ids , category ) );
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
