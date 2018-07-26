// Template modeling

#include "gappy_pattern_model.h"
#include "gappy_pattern_model_sampler.h"
#include "gist.h"
// TODO : included only as it contains the definition of init_random => can we move this definition to a more generic include file (module ?) ?
#include "probabilistic_object.h"
#include "tree.h"
#include "parameters.h"

#include <glog/logging.h>
//#include <glog/vlog_is_on.h>
#include <vector>

int main(int argc, char** argv) {

  /* init logging machinery */
  google::InitGoogleLogging(argv[0]);

  LOG(INFO) << "Starting template modeling ...";

  /* parse command line flags */
  LOG(INFO) << "Parsing command line arguments ...";
  google::ParseCommandLineFlags(&argc, &argv, true);
  
  /* do i still need this ? */
  init_random(FLAGS_random_seed);

  /* 0 - create new corpus */
  LOG(INFO) << "Creating new corpus ...";
  // TODO : provide the corpus root path as an argument ?
  const Corpus corpus = Corpus();

  /* 1 - instantiate our (empty) model */
  GappyPatternModel model( FLAGS_gappy_patterns_lambda , FLAGS_gappy_patterns_dp_alpha );
  // TODO : MultiSlotTypeTemplateModel model( FLAGS_template_dp_lambda , FLAGS_template_dp_alpha , FLAGS_slot_type_dp_alpha, FLAGS_gappy_patterns_lambda , FLAGS_gappy_patterns_dp_alpha );
  
  //boost::archive::binary_iarchive ia(ifs);
  //ia >> BOOST_SERIALIZATION_NVP(h);

  /* 2 - instantiate our model sampler */
  // TODO : is the model really trained via sampling ? should this be called a "trainer" ?
  GappyPatternModelSampler model_sampler = GappyPatternModelSampler(corpus,FLAGS_max_iterations);
  
  /* training/sampling */
  /* we use line_no as the document id, but the corresponding data is assumed to be uniformly distributed */
  model_sampler.train(model);

  /* compute perplexity of held-out data ( this cause the log-likelihood of each document to be written to STDOUT */
  /* TODO: if we don't need this value maybe there is a better way of organizing all this */
  double aggregate_log_likelihood = model.log_likelihood(corpus);

  /* release logging machinery */
  google::ShutdownGoogleLogging();

  return 0;

}
