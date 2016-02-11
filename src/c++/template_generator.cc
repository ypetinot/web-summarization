#include "MultipleStringAligner.h"
#include "parameters.h"

#include <iostream>
#include <fstream>
#include <string>
#include <tr1/memory>

#include <glog/logging.h>

/* read input strings on STDIN or from a file */
/* wid::word_normalized */

// http://stackoverflow.com/questions/2159452/c-assign-cin-to-an-ifstream-variable
struct noop {
  void operator()(...) const {}
};

int main(int argc, char** argv) {

  /* instantiate multiple string aligner */
  MultipleStringAligner msa;

  std::string filename(argv[1]);

  tr1::shared_ptr<istream> input;
  if (filename == string("-")) {
    input.reset(&cin, noop());
  }
  else if (filename.length()) {
    LOG(INFO) << "processing input from file: " << filename;
    input.reset(new ifstream(filename.c_str()));
  }
  else {
    LOG(ERROR) << "please provide a valid filename as a source for template generation. Aborting ...";
    exit(1);
  };

  vector< tr1::shared_ptr<WordLattice> > input_strings;

  /* read in input data */
  while( ! input->eof() ) {

    std::string line;
    getline(*input,line);

    if ( ! line.length() ) {
      continue;
    }

    WordLattice* wlp = WordLattice::buildWordLattice( line );
    if ( ! wlp ) {
      LOG(ERROR) << "unable to create word lattice for input string: " << line;
      continue;
    }

    tr1::shared_ptr<WordLattice> wl( wlp );
    input_strings.push_back( wl );

  }

  return 0;

}
