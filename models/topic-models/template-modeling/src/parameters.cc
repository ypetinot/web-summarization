#include "parameters.h"

// The GEM(m, \pi) distribution hyperparameter m, controls the "proportion of
// general words relative to specific words"
DEFINE_double(gem_m,
              0.1,
              "m reflects the proportion of general words to specific words");

// The GEM(m, \pi) hyperparameter \pi: reflects how strictly we expect the
// documents to adhere to the m proportions.
DEFINE_double(gem_pi,
              0.1,
              "reflects our confidence in the setting m");

// Model file to write to/read from (should be clear from context)
DEFINE_string(model,
	      "",
	      "serialized NCRP model");

// Gist data
DEFINE_string(gist_data,
	      "",
	      "gist data file");

// maximum number of (gibbs) iterations to run for.
DEFINE_int32(max_iterations,
	     1,
	     "max numer of (gibbs) iterations");

DEFINE_int32(random_seed,
	     101,
	     "what seed value to use");

// Poisson distribution parameter - top-level template length
DEFINE_double(template_dp_lambda,
	      2.0,
	      "lambda for the Poisson distribution controlling the length of top-level templates");

// Dirichlet Process alpha - top-level templates
DEFINE_double(template_dp_alpha,
	      1.0,
	      "concentration parameter for the Dirichlet Process controlling the (multinomial) distribution of top-level templates");

// Dirichlet Process alpha - slot types
DEFINE_double(slot_type_dp_alpha,
	      1.0,
	      "concentration parameter for the Dirichlet Process controlling the (multinomial) distribution of slot types in top-level templates");


// Poisson distribution parameter - gappy pattern length
DEFINE_double(gappy_patterns_lambda,
	      2.0,
	      "lambda for the Poisson distribution controlling the number of words occurring in gappy patterns");

// Dirichlet Process alpha - gappy patterns
DEFINE_double(gappy_patterns_dp_alpha,
	      1.0,
	      "concentration parameter for the Dirichlet Process controlling the (multinomial) distribution of gappy patterns");
