#ifndef __CORPUS_H__
#define __CORPUS_H__

#include "definitions.h"
#include "gist.h"
#include "strutil.h"

#include <glog/logging.h>
#include <google/dense_hash_map>
#include <fstream>
#include <tr1/memory>
#include <vector>

#include "language_model.h"

using namespace google;
using namespace google::protobuf;
using namespace std;

// Class provides a proxy to hold corpus-level statistics
// TODO: add capability to split instance into sub-corpora (e.g. train/test/test) and/or sample
class SequenceCorpus {
  
 public:
  
  /* default constructor */
  SequenceCorpus():
    unigram_language_model() {
      /* nothing */
  }

  /* unigram model getter */
  const UnigramLanguageModel& get_unigram_model() const {
    return unigram_language_model;
  }
  
  /* load sequence data */
  list< tr1::shared_ptr< SequenceRecord > > load_web_summary_data(const string& filename) {

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
      string raw_sequence_data = tokens[1];
      string path = tokens[2];

      /* Map path to actual Category instance */
      /* TODO ! */
      //Category* category = TreeManager ...
      tr1::shared_ptr<Category> category( new Category( path ) );
      tr1::shared_ptr<SequenceRecord> gist( new SequenceRecord( url , raw_sequence_data , category ) );
      gists.push_back( gist );

      /* collect word frequency data */
      const Sequence& sequence = gist.get()->sequence;
      unsigned number_of_words = sequence.size();
      for ( unsigned int i = 0; i < number_of_words; i++ ) {
	unsigned int word = sequence.get_token( i );
	unigram_language_model.register_word_instance( sequence , word );
      }

    }

    return gists;

  }
  
  /* get underlying set of sequences */
  const list<Sequence> get_sequences() const {
    list<Sequence> result;
    for (typename list< tr1::shared_ptr<SequenceRecord> >::const_iterator iter = gists.begin() ; iter != gists.end() ; ++iter ) {
      result.push_back((*iter)->sequence);
    }
    return result;
  }
  
 protected:

  /* complete set of sequence records */
  list< tr1::shared_ptr<SequenceRecord> > gists;

  /* unigram language model */
  UnigramLanguageModel unigram_language_model;
 
};

#endif
