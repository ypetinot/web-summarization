#ifndef __CORPUS_H__
#define __CORPUS_H__

#include "definitions.h"
#include "gist.h"
#include "strutil.h"
#include "word_sequence_corpus.h"

#include <glog/logging.h>
#include <google/dense_hash_map>
#include <fstream>
#include <tr1/memory>
#include <vector>

using namespace google;
using namespace google::protobuf;
using namespace std;

// TODO : is this class exclusively meant to hold corpus-level statistics ?

template< class T , class G > class Corpus {

 public:
  
  /* constructor */
  Corpus()
#if 0
_template_base_distribution(*this,template_poisson_lambda),_slot_type_base_distribution(*this),
#endif
    {
      /* nothing */
    }

  /* load web summary data */
  list< tr1::shared_ptr<T> > load_web_summary_data(const string& filename) {

    ifstream input_file(filename.c_str());
    CHECK(input_file.is_open());

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

      tr1::shared_ptr<T> gist( new T( url , word_ids , category ) );
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
  
  /* get underlying set of sequences */
  //list< tr1::shared_ptr<T> >
  const WordSequenceCorpus<T> get_summaries() const {
    list< tr1::shared_ptr<T> > result;
    for (typename list< tr1::shared_ptr<G> >::const_iterator iter = gists.begin() ; iter != gists.end() ; ++iter ) {
      result.push_back( *iter );
    }
    return result;
  }
  
 protected:

 list< tr1::shared_ptr<G> > gists;
 
};

#endif
