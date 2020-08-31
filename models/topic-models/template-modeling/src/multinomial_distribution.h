#ifndef __MULTINOMIAL_DISTRIBUTION__
#define __MULTINOMIAL_DISTRIBUTION__

#include "distribution.h"

#include <glog/logging.h>
#include <google/dense_hash_map>

/* TODO : can we avoid having this dependency ? (or at least replace it by a standard library) */ 
#include "hashing.h"

using namespace google;

/* TODO : reintroduce to notion of DiscreteDistribution to differentiate between e.g. Beta distributions and Multinomial distributions with an arbitrary (but finite) number of dimensions */

/* discrete/categorical/multinomial distribution - a distribution over category labels */
template< class T > class MultinomialDistribution: public Distribution<T> {

 public:

  /* constructor with id */
  MultinomialDistribution(const string id):
    _total_event_count(0),
    _id(id) {
    /* init category --> count mapping */
    _category_event_counts.set_empty_key("__PATTERN_EMPTY_KEY__");
    _category_event_counts.set_deleted_key("__PATTERN_DELETED_KEY__");    
  }
  
  /* default constructor */
  MultinomialDistribution():
    /* assumes constructor delegation is available */
    MultinomialDistribution("__DEFAULT_MULTINOMIAL_ID__") {
    /* nothing */
  }

  virtual double log_probability( const T& event ) {

    unsigned long instance_category_count = get_instance_count(event);
    unsigned long total_instance_count = get_total_event_count();
    
    /* return log probability of event's category */
    /* TODO : add assertion/check for the case where instance_category_count is equal to zero */
    //if ( instance_category_count ) {
    return log( instance_category_count / total_instance_count ); 
    //}
      
  }

  /* add instance */
  unsigned int add_instance( const T& instance ) {

    string instance_representation = instance.as_string();
    string instance_representation_log = instance.as_string_log();
    
    unsigned int incremented_count = get_instance_count( instance ) + 1;
    if ( incremented_count == 1 ) {
      LOG(INFO) << "[" << _id << "] Instantiated new object --> " << instance_representation_log;
    }
    else {
      LOG(INFO) << "[" << _id << "] Added instance for object (" << incremented_count << ") --> " << instance_representation_log;
    }

    _category_event_counts[ instance_representation ] = incremented_count;
    _total_event_count++;
    
    return incremented_count;
    
  }

  /* remove instance */
  unsigned int remove_instance( const T& instance ) {

    CHECK( _total_event_count > 0 );
    
    string instance_representation = instance.as_string();
    string instance_representation_log = instance.as_string_log();

    //    LOG(INFO) << "[" << _id << "] Removing instance of object --> " << instance_representation_log;

    /* locate entry for this instance */
    dense_hash_map<string, unsigned long, MurmurHash2, eqstring>::const_iterator iter = _category_event_counts.find( instance_representation );
    
    CHECK( iter != _category_event_counts.end() );
    unsigned int current_count = (*iter).second;
    CHECK( current_count > 0 );
    
    LOG(INFO) << "[" << _id << "] Removing instance of object (" << current_count << ") --> " << instance_representation_log;

    unsigned int new_count = _category_event_counts[ instance_representation ] = current_count - 1;
    
    if ( ! new_count ) {
      _category_event_counts.erase( instance_representation );
      LOG(INFO) << "[" << _id << "] Removed object --> " << instance_representation_log;
    }
    
    _total_event_count--;
    
    return new_count;
    
  }

  /* get count a specific instance */
  unsigned long get_instance_count( const T& instance ) const {

    /* 1 - event's category is the event's string representation */
    /* Note : this implicitly requires that type T derives from Stringifiable */
    string instance_representation = instance.as_string();
    
    dense_hash_map<string, unsigned long, MurmurHash2, eqstring>::const_iterator iter = _category_event_counts.find( instance_representation );
    
    if ( iter == _category_event_counts.end() ) {
      return 0;
    }
    
    unsigned int result = (*iter).second;
    CHECK( result <= _total_event_count ); 
    
    return result;
    
  }

  /* get total instances count */
  unsigned long get_total_event_count() const {
    return _total_event_count;
  }
  
 protected:

  /* id of this multinomial (for logging purposes only) */
  string _id;
  
  /* total event count */
  unsigned long _total_event_count;

  /* map category name to category event count */
  dense_hash_map<string, unsigned long, MurmurHash2, eqstring> _category_event_counts;  
  
};

#endif
