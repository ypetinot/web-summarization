#include "viterbi_decoder.hh"
#include "LanguageModel_SRILM.hh"
#include "TranslationModel_IBM_Model1.hh"
#include "TokenSequence.hh"
#include "ProbabilisticTokenSequence.hh"
#include <iostream>
#include <string>
#include <tr1/memory>

#include <boost/program_options.hpp>

namespace po = boost::program_options;

using namespace std;

int main(int argc, char** argv) {

  string lm_type;
  string lm_file;
  string lm_server;
  int lm_order;

  string tm_type;
  string tm_file;

  string source_vocabulary;
  string output_vocabulary;

  int n_tokens;

  // Declare the supported options.
  po::options_description desc("Allowed options");
  desc.add_options()
    ("help", "produce help message")
    ("lm-type", po::value<string>(&lm_type)->default_value("srilm-server"), "select which language model type to use")
    ("lm-server-info", po::value<string>(&lm_server), "language model server host and port information")
    ("lm-order", po::value<int>(&lm_order)->default_value(3), "order of the language model")
    ("tm-type", po::value<string>(&tm_type)->default_value("ibm-model-1"), "select which translation model type to use")
    ("tm-file", po::value<string>(&tm_file), "translation model file")
    ("source-vocabulary", po::value<string>(&source_vocabulary), "source vocabulary")
    ("output-vocabulary", po::value<string>(&output_vocabulary), "output_vocabulary")
    ("n-tokens", po::value<int>(&n_tokens)->default_value(0), "number of input tokens to decode")
    ;

  po::variables_map vm;
  po::store(po::parse_command_line(argc, argv, desc), vm);
  po::notify(vm);    

  if (vm.count("help")) {
    cout << desc << "\n";
    // cerr << "Usage: " << argv[0] << " <language_model> <translation_model>" << endl;
    return 1;
  }

  /* instantiate language model */
  tr1::shared_ptr<NgramLanguageModel> lm;
  if ( lm_type == "srilm-server" ) {
    lm = tr1::shared_ptr<NgramLanguageModel>(SRI::LanguageModel::loadLanguageModel(lm_server, output_vocabulary, lm_order, true));
  }
  else {
    cerr << "Invalid Language Model type requested: " << lm_type << endl;
  }

  cerr << "Successfully loaded language model !" << endl;

  /* instantiate translation model */
  tr1::shared_ptr<TranslationModel> tm;
  if ( tm_type == "ibm-model-1" ) {
    tm = tr1::shared_ptr<TranslationModel>(IBM::Model1::TranslationModel::loadTranslationModel(tm_file,source_vocabulary,output_vocabulary));
  }
  else {
    cerr << "Invalid Translation Model type requested: " << tm_type << endl;
  }

  cerr << "Successfully loaded translation model !" << endl;

  /* instantiate decoder */
  ocelot::ViterbiDecoder ovd(*lm, *tm);

  cerr << "Successfully instantiated Viterbi decoder !" << endl;

  cerr << "Starting data processing ..." << endl;

  /* process one line at a time */
  string line;
  while( getline(cin, line) ) {

    /* parse line into a TokenSequence */
    TokenSequence ts = TokenSequence::getTokenSequence(line, " ");

    /* decode sequence */
    ProbabilisticTokenSequence pts = ovd.decode(ts, n_tokens);

    /* ouput decoded sequence together with probability */
    cout << pts.getProbability() << "\t" << pts.toString(" ") << endl;

  }  

}
