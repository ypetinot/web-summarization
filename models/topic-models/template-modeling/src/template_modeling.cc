// Template modeling

#include "gist.h"
#include "template.h"
#include "template_sampler.h"
#include "tree.h"
#include "parameters.h"
#include "probabilistic_object.h"

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
  Corpus corpus( FLAGS_template_dp_lambda , FLAGS_template_dp_alpha , FLAGS_slot_type_dp_alpha, FLAGS_gappy_patterns_lambda , FLAGS_gappy_patterns_dp_alpha );

  /* 1 - instantiate our (empty) model */
  TemplateModel model( corpus );
    
  //boost::archive::binary_iarchive ia(ifs);
  //ia >> BOOST_SERIALIZATION_NVP(h);
 
  /* sample topic assignments */
  /* can we do this on a global level using run() ? */
  /* we use line_no as the document id, but the corresponding data is assumed to be uniformly distributed */
  //h.run(FLAGS_max_gibbs_iterations, 0, false);

  /* compute perplexity of held-out data ( this cause the log-likelihood of each document to be written to STDOUT */
  /* TODO: if we don't need this value maybe there is a better way of organizing all this */
  //double aggregate_log_likelihood = h.compute_log_likelihood(true);

  /* release logging machinery */
  google::ShutdownGoogleLogging();

  return 0;

}
