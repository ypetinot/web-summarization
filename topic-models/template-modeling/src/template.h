#ifndef __TEMPLATE_H__
#define __TEMPLATE_H__

#include "definitions.h"
#include "template_element.h"
#include "template_slot.h"

#include <list>
#include <tr1/memory>
#include <string>
#include <vector>

using namespace std;

/**

   Design notes:

   * The template class maintains the templatic status at all locations for the target gist, this is independent from the registerer template for that
   gist (in fact the template may very well not be registered at all).

 */

class Template: public PoissonProbabilisticObject {

 public:

  /* constructor ( with random initialization ) */
  Template( Gist* gist );

  /* copy constructor */
  Template( const Template& t );

  /* get number of elements */
  unsigned int get_element_count() const;

  /* get element */
  tr1::shared_ptr<TemplateElement> get_element( unsigned int i ) const;

  /* get element at word location */
  const tr1::shared_ptr<TemplateSlot>& get_slot_at_word_location( unsigned int i ) const;

  /* get all slots in this template */
  vector< tr1::shared_ptr<TemplateSlot> > get_slots() const;

  /* return template string */
  string get_template_string() const;

  /* return gist/template data as string */
  string as_string() const;

  /* return gist/template data as string (log content) */
  string as_string_log() const;
  
  /* as_string with more options */
  string _as_string( bool abstract_slot_content , bool include_slot_type , bool include_slot_length ) const;

  /* get templatic status for a specific word */
  int get_templatic_status( unsigned int index ) const;

  /* get underlying gist */
  const Gist* get_gist() const;

  /* tentatively (?) update template state */
  tr1::shared_ptr<Template> transition( unsigned int index , int state );

  /* compute the probability of this object */
  virtual double log_probability();

  /* register template with underlying dp */
  void register_with_dp();

  /* unregister template with underlying dp */
  void unregister_with_dp();

  /* flip templatic status at a specific location */
  void flip_templatic_status( unsigned int index );

  /* resample all slot types for the target gist's template */
  /* TODO: can we do without this method ? */
  void sample_slot_types_and_register();

  /* check whether we have a slot status at a specific location */
  bool is_slot( unsigned int index ) const;

  /* check whether the target location is templatic */
  bool is_templatic( unsigned int index ) const;
  
  /* check structural consistency */
  bool check_consistency() const;

 protected:

  /* underlying gist */
  Gist* _gist;

  /* templatic status */
  vector< short int > _templatic_status;

  /* init - random initialization */
  void _init();

  /* append element */
  void append( TemplateElement* te , bool status );

  /* List providing the top level templatic structure of the underlying gist */
  vector< tr1::shared_ptr<TemplateSlot> > _slots;

  /* whether a slot has been assigned for the target index */
  vector< short int > _slots_set;

  /* truncate slot on its left side */
  void truncate_slot_left( tr1::shared_ptr<TemplateSlot> slot , unsigned int index );

  /* truncate slot on its right side */
  void truncate_slot_right( tr1::shared_ptr<TemplateSlot> slot , unsigned int index );

  /* truncate slot */
  void truncate_slot( tr1::shared_ptr<TemplateSlot> slot , unsigned int index );

  /* remove slot */
  void remove_slot( tr1::shared_ptr<TemplateSlot> slot );

  /* remove slot at a specific location */
  void shrink_slot( unsigned int index );

  /* get slot at a specific location */
  tr1::shared_ptr<TemplateSlot> get_slot( unsigned int index ) const;

  /* set slot (status) at a specific location (shouldn't this all be done through flip ?)*/
  void set_slot( unsigned int index );

  /* set templatic (status) at a specific location (shouldn't this all be done through flip ?)*/
  void set_templatic( unsigned int index );

  /* set (underlying) status - does not handle flipping logic */
  void copy_status( unsigned int index , unsigned int inherit_from_index , int status );

  /* check the validity of the target index */
  bool _valid_index( unsigned int index ) const;

  /* get underlying dp */
  DirichletProcess<Template>& _get_underlying_dirichlet_process() const;

};

#endif
