#ifndef __SLOT_TYPE_BASE_DISTRIBUTION_H__
#define __SLOT_TYPE_BASE_DISTRIBUTION_H__

class SlotTypeBaseDistribution: public Distribution {

 public:
  
  /* constructor */
  SlotTypeBaseDistribution( const Corpus& corpus );

  /* compute the probability of a specific event */
  virtual double log_probability( const CountableObject& event );

 protected:

};

#endif
