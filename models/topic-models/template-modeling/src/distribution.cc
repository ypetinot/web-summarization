#include "distribution.h"

#include "statistics.h"

#include <glog/logging.h>

/* constructor */
Distribution::Distribution() {
  /* nothing */
}

/* probability of a given event in the corpus */
double probability( const T& event ) {
  return exp( log_probability( event ) );
}
