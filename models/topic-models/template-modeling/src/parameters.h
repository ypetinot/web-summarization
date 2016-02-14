#ifndef __PARAMETERS_H__
#define __PARAMETERS_H__

#include <gflags/gflags.h>

// Eta controls the amount of smoothing within the per-topic word distributions.
// Higher eta = more smoothing. Also used in the GEM sampler.
DECLARE_double(eta);

// maximum number of (gibbs) iterations to run for.
DECLARE_int32(max_iterations);

// One problem with Gibbs sampling is that nearby samples are highly
// correlated, throwing off the empirical distribution. In practice you need to
// wait some amount of time before reading each (independent) sample.
DECLARE_int32(sample_lag);

// The random seed
DECLARE_int32(random_seed);

// Alpha controls the topic smoothing, with higher alpha causing more "uniform"
// distributions over topics. This is replaced by m and pi in the GEM sampler.
DECLARE_double(ncrp_alpha);

// Gamma controls the probability of creating new brances in both the
// Multinomial and GEM sampler; has no effect in the fixed-structure sampler.
DECLARE_double(ncrp_gamma);

// The GEM(m, \pi) distribution hyperparameter m, controls the "proportion of
// general words relative to specific words"
DECLARE_double(gem_m);

// The GEM(m, \pi) hyperparameter \pi: reflects how strictly we expect the
// documents to adhere to the m proportions.
DECLARE_double(gem_pi);

// Whether or not to use the GEM sampler. The Multinomial sampler currently is
// more flexible as it allows the tree structure to be a DAG; the GEM sampler
// might not work yet with DAGs.
DECLARE_bool(gem_sampler);

// If unset, then just throw away extra edges that cause nodes to have multiple
// parents. Enforcing a tree topology.
DECLARE_bool(use_dag);

// Should we cull topics that only have one document?
DECLARE_bool(cull_unique_topics);

// Is the input text already vocabulary-mapped ?
DECLARE_bool(map_vocabulary);

// Size of the target vocabulary (assume the vocabulary has already been mapped ?)
DECLARE_int32(vocabulary_size);

// Model file to write to/read from (should be clear from context)
DECLARE_string(model);

// Gist data
DECLARE_string(gist_data);

// Poisson distribution parameter - top-level template length
DECLARE_double(template_dp_lambda);

// Dirichlet Process alpha - top-level templates
DECLARE_double(template_dp_alpha);

// Dirichlet Process alpha - slot types
DECLARE_double(slot_type_dp_alpha);

// Poisson distribution parameter - gappy pattern length
DECLARE_double(gappy_patterns_lambda);

// Dirichlet Process alpha - gappy patterns
DECLARE_double(gappy_patterns_dp_alpha);

#endif
