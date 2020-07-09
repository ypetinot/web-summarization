#ifndef __WORD_SEQUENCE_CORPUS_H__
#define __WORD_SEQUENCE_CORPUS_H__

//typedef int Word;

//typedef list<Word> WordSequence;
template< class T > class WordSequence: public list<T> {
  /* nothing */
};

//typedef list<WordSequence> WordSequenceCorpus;
template< class T > class WordSequenceCorpus: public list< WordSequence< T > > {
  /* nothing */
};

#endif
