#include "slot_type_base_distribution.h"

/* constructor */
SlotTypeBaseDistribution::SlotTypeBaseDistribution( const Corpus& corpus )
  :Distribution(corpus) {

  /* nothing */

}

/* compute the probability of a specific event */
double SlotTypeBaseDistribution::log_probability( const CountableObject& event ) {

  if ( even->count() == 0 ) {
    return 1;
  }

  return 0;

}
