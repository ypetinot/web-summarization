#ifndef __DIRICHLET_PROCESS__
#define __DIRICHLET_PROCESS__

#include "distribution.h"
#include "probabilistic_object.h"

#include <glog/logging.h>
#include <google/dense_hash_map>
#include <string>
#include <vector>
#include <set>
#include <stack>
#include <tr1/memory>

#include "hashing.h"

using namespace google;
using namespace std;

template< class T >
class DirichletProcess {

 public:
  
  /* constructor */	
 DirichletProcess( string id , double alpha )
   :_id(id),_alpha(alpha),_total_instances(0) {
    
    /* init pattern --> count mapping */
    _object_map.set_empty_key("__PATTERN_EMPTY_KEY__");
    _object_map.set_deleted_key("__PATTERN_DELETED_KEY__");
    
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

    _object_map[ instance_representation ] = incremented_count;
    _total_instances++;
    
    return incremented_count;
    
  }

  /* remove instance */
  unsigned int remove_instance( const T& instance ) {

    CHECK( _total_instances > 0 );
    
    string instance_representation = instance.as_string();
    string instance_representation_log = instance.as_string_log();

    //    LOG(INFO) << "[" << _id << "] Removing instance of object --> " << instance_representation_log;

    /* locate entry for this instance */
    dense_hash_map<string, unsigned int, MurmurHash2, eqstring>::const_iterator iter = _object_map.find( instance_representation );
    
    CHECK( iter != _object_map.end() );
    unsigned int current_count = (*iter).second;
    CHECK( current_count > 0 );
    
    LOG(INFO) << "[" << _id << "] Removing instance of object (" << current_count << ") --> " << instance_representation_log;

    unsigned int new_count = _object_map[ instance_representation ] = current_count - 1;
    
    if ( ! new_count ) {
      _object_map.erase( instance_representation );
      LOG(INFO) << "[" << _id << "] Removed object --> " << instance_representation_log;
    }
    
    _total_instances--;
    
    return new_count;
    
  }

  /* get count a specific instance */
  unsigned int get_instance_count( const T& instance ) const {

    string instance_representation = instance.as_string();
    
    dense_hash_map<string, unsigned int, MurmurHash2, eqstring>::const_iterator iter = _object_map.find( instance_representation );
    
    if ( iter == _object_map.end() ) {
      return 0;
    }
    
    unsigned int result = (*iter).second;
    CHECK( result <= _total_instances ); 
    
    return result;
    
  }
  
  /* new probability */
  double new_probability( T& instance ) const {

    unsigned int number_instances_single = get_instance_count( instance );
    
    /* 2 - get the total number of patterns instances */
    unsigned int number_instances_total = get_total_instances();
    
    /* 3 - compute probability of a new instance */
    double probability_base = instance.probability();
    double probability_new = ( number_instances_single + _alpha * probability_base ) / ( number_instances_total + _alpha );
    
    CHECK_GE( probability_new , 0 );
    CHECK_LE( probability_new , 1 );
    
    return probability_new;
    
  }

  /* transition probability */
  double transition_probability( T& from , T& to ) const {

    unsigned int number_instances_current_pattern = get_instance_count( from );
    if ( ! number_instances_current_pattern ) {
      LOG(WARNING) << "Correcting instance count for transition probability ...";
      number_instances_current_pattern = 1;
    }

    unsigned int number_instances_new_pattern = get_instance_count( to );
    
    /* compute probability of adding target word to this gappy pattern */
    double probability = _dp_probability( number_instances_new_pattern , to.probability() , number_instances_current_pattern , from.probability() );
    
    CHECK( probability );
    
    return probability;
    
  }
  
  /* multinomial probability */
  double multinomial_probability( T& instance ) const {

    return _dp_probability( get_instance_count( instance ) , instance.probability() , get_total_instances() , 1 );
    
  }

  /* get total instances count */
  long get_total_instances() const {
  
    return _total_instances;
    
  }

  /* get instance ids */
  vector<string> get_instance_ids() const {

    vector<string> ids;
    for ( dense_hash_map<string, unsigned int, MurmurHash2, eqstring>::const_iterator iter = _object_map.begin(); iter != _object_map.end(); ++iter ) {
      ids.push_back( (*iter).first );
    }
    
    return ids;

  }

 protected:

  /* id of this process */
  string _id;

  /* gappy pattern counts */
  dense_hash_map<string, unsigned int, MurmurHash2, eqstring> _object_map;

  /* concentration parameter */
  double _alpha;
  
  /* total number of pattern instances */
  long _total_instances;

  /* dp probability ( unormalized ) */
  double _dp_probability( double event_count , double event_probability_mass , double reference_count , double reference_probability_mass ) const {

    double probability = ( event_count + _alpha * event_probability_mass ) / ( reference_count + _alpha * reference_probability_mass );
    
    CHECK_GE( probability , 0 );
    
    /* TODO: verify that this is true ! */
    // Unnormalized !
    //    CHECK_LE( probability , 1 );

    return probability;

  }

};

#if 0
class TransitionDirichletProcess: public DirichletProcess {

 public:

  /* constructor */
  TransitionDirichletProcess( Distribution& base_distribution , double alpha );



}
#endif

#endif
