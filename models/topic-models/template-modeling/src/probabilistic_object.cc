#include "probabilistic_object.h"
#include <math.h>

/* compute the probability of this object */
double ProbabilisticObject::probability() {

  return exp( this->log_probability() );

}
