#ifndef __SEQUENCE_H__
#define __SEQUENCE_H__

#include <boost/lexical_cast.hpp>
#include <list>
#include <string>

#include "strutil.h"

using namespace google::protobuf;

typedef std::string Token;

/* Note : this is only useful in case we want to ultimately optimize the implementation of Sequence functionality ? */
class Sequence: public std::vector<TOKEN> {

 protected:

  vector<TOKEN> _tokenize(const string& raw_string) {

    vector<string> words;
    SplitStringUsing(raw_string, " ", &words);
    
    vector<long> word_ids;
    word_ids.push_back( WORD_ID_BOG ); /* add bog node */
    for (vector<string>::iterator it = words.begin() ; it != words.end(); ++it) {
      word_ids.push_back( atol( (*it).c_str() ) );
    }
    word_ids.push_back( WORD_ID_EOG ); /* add eog node */

    return word_ids;
    
  }
  
 public:

  /* constructor */
  Sequence(const string& raw_string):
    vector<TOKEN>(_tokenize(raw_string)) {
    /* nothing */
  }

  /* destructor */
  virtual ~Sequence() {
    /* nothing */
  }
  
  /* get word at specified index */
  TOKEN get_word( unsigned int index ) const {
    CHECK_GE( index , 0 );
    CHECK_LE( index , size() - 1 );
    return at(index);
  }

  /* get word at specified index (returned as a string object) */
  string get_word_as_string( unsigned int index ) const {
    TOKEN word_id = get_word( index );
    return boost::lexical_cast<std::string>(word_id);
  }

  /* generate string representation containing the template information */
  string as_string(bool detailed = false) const;
  
};

class TemplaticSequence: public Sequence {

public:

  /* set templatic marker at the specified index */
  void set_templatic( unsigned int index , bool status ) {
    bool old_status = w_templatic[ index ];
    if ( old_status != status ) {
      /* Update model if the template status changes ? */
      /* TODO */
      w_templatic[ index ] = status;
    }
  }

  /* unset template */
  void unset_template();

  /* sample template at specific location */
  void sample_template_at_location( unsigned int i );
  
 TemplaticSequence(std::string raw_sequence_string):Sequence(raw_sequence_string) {
    /* tokenize raw sequence string */
    /* TODO */
  }

  // TODO : reintroduce if needed
  ///* default constructor - only needed so that TokenSequence (and its descendant classes) can be used with containers */
  //// TODO : make this method protected
  //TemplaticSequence() {
  //  /* nothing */
  //}
  
 protected:

  /* Each word is either templatic or non templatic */
  vector<bool> w_templatic;
  
};

#endif
