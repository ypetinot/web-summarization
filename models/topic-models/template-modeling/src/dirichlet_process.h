#ifndef __DIRICHLET_PROCESS__
#define __DIRICHLET_PROCESS__

#include "multinomial_distribution.h"
#include "probabilistic_object.h"

#include <glog/logging.h>
#include <string>
#include <vector>
#include <set>
#include <stack>
#include <tr1/memory>

using namespace google;
using namespace std;

/* TODO : is it fair to say a Dirichlet Process is a Multinomial Distribution with a countably-infinite number of dimensions/categories ? */
template< class T > class DirichletProcess: public MultinomialDistribution<T> {

 protected:

  /* base distribution */
  const MultinomialDistribution<T>& _base_distribution;
  
 public:
  
  /* constructor */
  DirichletProcess( string id , double alpha , const MultinomialDistribution<T>& base_distribution)
    :MultinomialDistribution<T>(id),_base_distribution(base_distribution),_alpha(alpha) {
    /* nothing */
  }

  /* probability currently assigned to an event by the underlying multinomial */
  double multinomial_probability( const T& instance ) const {
    
    unsigned long number_instances_single = get_instance_count( instance );
    
    /* 2 - get the total number of patterns instances */
    unsigned long number_instances_total = MultinomialDistribution<T>::get_total_event_count();
    
    /* 3 - compute probability of a new instance */
    double probability_base = _base_distribution.probability( instance );

    double probability_new = _dp_probability( number_instances_single , probability_base , number_instances_total , 1 );
    
    CHECK_GE( probability_new , 0 );
    CHECK_LE( probability_new , 1 );
    
    return probability_new;
    
  }

  /* TODO : this is not quite part of the concept of a DP, or is it ? */
  /* transition probability */
  double transition_probability( T& from , T& to ) const {

    unsigned int number_instances_current_pattern = get_instance_count( from );
    if ( ! number_instances_current_pattern ) {
      LOG(WARNING) << "Correcting instance count for transition probability ...";
      number_instances_current_pattern = 1;
    }

    unsigned int number_instances_new_pattern = get_instance_count( to );
    
    /* compute probability of adding target word to this gappy pattern */
    double probability = _dp_probability( number_instances_new_pattern ,
					  _base_distribution.probability( to ) ,
					  number_instances_current_pattern ,
					  _base_distribution.probability( from ) );
    
    CHECK( probability );
    
    return probability;
    
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

  /* gappy pattern counts */
  dense_hash_map<string, unsigned int, MurmurHash2, eqstring> _object_map;

  /* concentration parameter */
  double _alpha;
  
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
