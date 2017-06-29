#ifndef __TEMPLATE_SLOT_H__
#define __TEMPLATE_SLOT_H__

/* A template slot abstracts the notion of a slot within a top level template */
/* The content of template slots is modeled using a gappy pattern model */

#include "definitions.h"
#include "probabilistic_object.h"
#include "registrable_object.h"
#include "template_element.h"

#include <deque>
#include <google/dense_hash_map>
#include <set>
#include <stack>
#include <tr1/memory>

/* TODO: replace this with standard code, I'm just copying this header file for now as it isn't core to the model itself */
#include "hashing.h"

using namespace google;

/* TODO : add a LocallyUpdateableObject */
class TemplateSlot: public StringifiableObject, public TemplateElement {

 public:

  /* constructor ( with random initialization ) */
  TemplateSlot( Gist* gist, unsigned int f , unsigned int t );

  /* copy constructor */
  TemplateSlot( const TemplateSlot& ts );

  /* get color */
  unsigned int get_color( unsigned int color_index );

  /* create gappy pattern for this location */
  tr1::shared_ptr<GappyPattern> create_gappy_pattern() const;

  /* is this element templatic */
  bool is_templatic() const;

  /* set (gappy) pattern color at the specified index */
  tr1::shared_ptr<GappyPattern> set_color( unsigned int index, bool new_color , unsigned int color = COLOR_NO_COLOR );
  
  /* unset (gappy) pattern color at the specified index */
  void unset_color( int index );

  /* get the number of (gappy) pattern colors in this gist */
  unsigned int get_number_of_colors() const;
  
  /* get number of free colors */
  unsigned int get_number_of_free_colors() const;
  
  /* get color at location */
  unsigned int get_color_at_location( int index ) const;

  /* set color at location */
  void set_color_at_location( int index , unsigned int color );
  
  /* get (gappy) pattern associated with the specified index */
  tr1::shared_ptr<GappyPattern> get_color_pattern_from_location( int index ) const;
  
  /* get (gappy) pattern associated with the specified color */
  tr1::shared_ptr<GappyPattern> get_color_pattern_from_color( unsigned int color ) const;
  
  /* get active colors */
  set<unsigned int> get_colors() const;

  /* as string */
  string as_string() const;

  /* complete sampling procedure for the target word */
  unsigned int sample_color( int index );
  
  /* full sample */
  void sample_full( bool iterative_registration = false );

  /* sample slot type */
  void sample_type();

  /* extend this slot */
  void extend( int index );

  /* shrink this slot */
  void shrink( int index );

  /* check consistency (public) */
  bool check_consistency() const;

  /* TODO : the type should not be a GappyPatternProcess => the string id of a GappyPatternProcess is however OK */
  /* get type */
  string const get_type() const;

  /* register coloring */
  void register_coloring();

  /* unregister coloring */
  void unregister_coloring();

 protected:

  /* slot type */
  GappyPatternProcess* _slot_type;

  /* color stack */
  stack<unsigned int> free_colors;
  
  /* color to words mapping */
  dense_hash_map<unsigned int, set<int>, MurmurHash2UnsignedInt, equnsignedint> colors_to_words;

  /* each non templatic word is associated with a color/gappy pattern */
  deque<unsigned int> w_colors;
  
  /* number of colors (gappy patterns) */
  unsigned int number_of_colors;

  /* init */
  void _init();

  /* check consistency */
  bool _check_consistency( bool check_active_colors = false ) const;

  /* sample next color given neutral state (no update) */
  unsigned int _sample_color( int location ) const;

  /* make sure we're dealing with a valid location in this slot */
  bool _valid_location( int index ) const;
  
  /* make sure we're dealing with a valid color id */
  bool _valid_color( unsigned int color_id ) const;

};

#endif
