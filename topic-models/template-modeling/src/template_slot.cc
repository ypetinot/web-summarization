#include "template_slot.h"

#include "gist.h"

#include <boost/lexical_cast.hpp>
#include <glog/logging.h>

/* constructor ( with random initialization ) */
/* TODO: potential inconsistency with the initial size for w_colors set to 0 */
TemplateSlot::TemplateSlot( Gist* gist, unsigned int f , unsigned int t )
  :RegistrableObject(),_slot_type(NULL),TemplateElement(gist,f,t),number_of_colors(0),w_colors(0) {

  /* init colors --> words mapping */
  /* TODO: switch to int keys */
  colors_to_words.set_empty_key(10000);
  colors_to_words.set_deleted_key(20000);

  /* randomly initialize slot type */
  /* TODO: can we not do this here ? */
  sample_type();

  /* ramdomly initialize coloring ( how ? ) */
  /* trick: we shrink the slot location to a single word and iteratively grow it to its expected size */
  /* TODO: can we do better ? */
  int real_to = to;
  to = from - 1;
  for ( int i = from; i <= real_to; i++ ) {

    /* extend slot */
    extend( i );

    /* resample color */
    sample_color( i );

  }

  /* just to be on the safe side */
  _check_consistency( true );

}

/* sample type */
/* implies a coloring resampling if the slot type changes */
void TemplateSlot::sample_full( bool iterative_registration ) {

  /* must be unregisted (GPP) */
  CHECK( ! this->registered() );
  
  /* 2 - sample type */
  /* --> one option for each type (plus a new type) */
  this->sample_type();

#if 0
    
    /* push free colors - one for each word in the gist */
    for (int i = from; i <= to; i++) {
      free_colors.push( i+1 );
    }
    
    /* individual word status initialization */
    for (int i = from; i <= to; i++) {
      
      /* gappy pattern color initialization */
      /* Note: to keep things simple, we assign each word to its own color */
      set_color( i - from , true );
      
    }
    
#endif
  
  /* 3 - sample coloring ... */
  for ( unsigned int i = get_from() ; i <= get_to() ; i++ ) {

    /* set color handles the iterative registration process */
    sample_color( i , iterative_registration );

    /* pb: can coloring be sampled w/out registration ??? */
    /* problem: full resampling is probably not compatible with the top-level sampling model ... */
    
    /* --> deconstruct (i.e. deregister iteratively), then reconstruct ... */

  } 

}

/* sample slot type */
/* TODO: ultimately this probably should be moved to the template level, since slot types are unlikely to be (conditionally) independent */
void TemplateSlot::sample_type() {

  /* must be unregisted (GPP) */
  /* necessarily --> coloring is attached to type
  CHECK( ! this->registered() );

  /* get list of existing slot types */
  vector< GappyPatternProcess* > slot_types = _gist->get_corpus().get_slot_types();

  /* one sampling option for each color type (plus a new one) */
  vector< double > slot_types_probability;
  DirichletProcess<GappyPatternProcess>& slot_type_dp = _gist->get_corpus().get_slot_type_dp();
  for ( vector< GappyPatternProcess* >::const_iterator iter = slot_types.begin(); iter != slot_types.end(); ++iter ) {
    bool slot_type_existing = ( slot_type_dp.get_instance_count( *( *iter ) ) != 0 );
    double slot_type_probability = slot_type_existing ? slot_type_dp.multinomial_probability( *( *iter ) ) : slot_type_dp.new_probability( *( *iter ) );
    slot_types_probability.push_back( slot_type_probability );
  }

  /* MISSING: type probability must factor out the coloring of the slot ? */

  /* resample the type of the current slot */
  unsigned int sampled_index = multinomial_sampler< GappyPatternProcess* >( slot_types , slot_types_probability );
  GappyPatternProcess* sampled_type = slot_types[ sampled_index ];
  
  /* finally set slot type */
  _slot_type = sampled_type;

}

/* copy constructor */
TemplateSlot::TemplateSlot( const TemplateSlot& ts )
  :TemplateElement(ts),
   _slot_type(ts._slot_type),free_colors(ts.free_colors),colors_to_words(ts.colors_to_words),
   w_colors(ts.w_colors),
   number_of_colors(ts.number_of_colors) {

  /* copy free colors */
  /* --> done via initializers list */

  /* just to be on the safe side */
  _check_consistency( true );

}

/* get color */
unsigned int TemplateSlot::get_color( unsigned int color_index ) {

  CHECK_GE( color_index , 0 );
  CHECK_LE( color_index , number_of_colors );

  /* TODO: is random access possible ? */
  dense_hash_map<unsigned int, set<int>, MurmurHash2UnsignedInt, equnsignedint>::iterator iter = colors_to_words.begin();
  while ( color_index-- > 0 ) {
    iter++;
  }

  /* an active color must have a non-empty set of words associated with it */
  CHECK( (iter->second).size() );

  return iter->first;

}

/* check consistency (public) */
bool TemplateSlot::check_consistency() const {

  return _check_consistency( true );

}

/* check colors consistency */
bool TemplateSlot::_check_consistency( bool check_active_colors ) const {

  CHECK( number_of_colors + free_colors.size() == length() );
  
  /* TODO: move this somewhere else ? */
  CHECK( w_colors.size() == ( to - from + 1 ) );
  
  if ( check_active_colors ) {

    for ( deque<unsigned int>::const_iterator iter = w_colors.begin(); iter != w_colors.end(); ++iter ) {
      CHECK( *iter != 0 );
    }

  }

  return true;

}

/* get number of free colors */
unsigned int TemplateSlot::get_number_of_free_colors() const {
  
  return free_colors.size();

}

/* set color of an individual word and return the corresponding color (gappy) pattern */
tr1::shared_ptr<GappyPattern> TemplateSlot::set_color( unsigned int i , bool new_color , unsigned int color ) {

  _check_consistency();

  unsigned int current_color = get_color_at_location( i );
  CHECK( current_color == COLOR_NO_COLOR );

  if ( new_color ) {
    CHECK( color == COLOR_NO_COLOR );
    color = free_colors.top();
    free_colors.pop();
    number_of_colors++;
  }

  /* actually update color assignment */
  set<int>& new_color_words = colors_to_words[ color ];
  CHECK( new_color || new_color_words.size() );
  unsigned int current_size = new_color_words.size();
  new_color_words.insert( i );
  CHECK( colors_to_words[ color ].size() == current_size + 1 );

  /* update color assignment for the target word */
  set_color_at_location( i , color );
  
  /* construct gappy pattern for new color */
  tr1::shared_ptr<GappyPattern> gappy_pattern = get_color_pattern_from_color( color );

  _check_consistency();

  return gappy_pattern;

}

/* unset (gappy) pattern color at the specified index */
void TemplateSlot::unset_color( int index ) {

  _check_consistency();

  /* determine color for the target word */
  unsigned int word_color = get_color_at_location( index );

  if ( word_color != COLOR_NO_COLOR ) {

    /* remove word from current color assignment */
    set<int>& current_color_words = colors_to_words[ word_color ];
    if ( current_color_words.size() == 1 ) {
      /* free this color */
      colors_to_words.erase( word_color );
      free_colors.push( word_color );
      number_of_colors--;

#ifndef TOP_LEVEL_TEMPLATIC
      // Can actually fail if we have only 1 or 2 words in this gist
      //      CHECK( number_of_colors );
#endif

    }
    else {
      /* remove this word from the current color */
      current_color_words.erase( index );
      CHECK( current_color_words.size() );
    }
    
    /* mark the target word with the no-color color */
    set_color_at_location( index , COLOR_NO_COLOR );

  }

  _check_consistency();

}

/* get the number of (gappy) pattern colors in this gist */
unsigned int TemplateSlot::get_number_of_colors() const {

  return number_of_colors;

}

/* get color (gappy) pattern associated with the target color */
tr1::shared_ptr<GappyPattern> TemplateSlot::get_color_pattern_from_color( unsigned int color ) const {

  CHECK( color );

  /* get current set of locations for the target color */
  dense_hash_map<unsigned int, set<int>, MurmurHash2UnsignedInt, equnsignedint>::const_iterator c2w_iter = colors_to_words.find( color );
  CHECK( c2w_iter != colors_to_words.end() );
  set<int> color_words = (*c2w_iter).second;
 
  tr1::shared_ptr<GappyPattern> gappy_pattern( new GappyPattern( *this ) );
  for (set<int>::const_iterator iter = color_words.begin(); iter != color_words.end(); iter++) {
    
    /* append current word */
    gappy_pattern->add_word( *iter );
    
  }
  /* TODO: compute probability for this string ? */

  return gappy_pattern;

}

/* get color (gappy) pattern associated with the target location */
tr1::shared_ptr<GappyPattern> TemplateSlot::get_color_pattern_from_location( int i ) const {

  /* determine color at index i */
  unsigned int color_at_i = get_color_at_location( i );

  return get_color_pattern_from_color( color_at_i );

}

/* get active colors */
set<unsigned int> TemplateSlot::get_colors() const {

  set<unsigned int> active_colors;
  for ( dense_hash_map<unsigned int, set<int>, MurmurHash2UnsignedInt, equnsignedint>::const_iterator iter = colors_to_words.begin(); iter != colors_to_words.end(); ++iter ) {
    active_colors.insert( (*iter).first );
  }

  return active_colors;

}

/* set color at location */
void TemplateSlot::set_color_at_location( int index , unsigned int color ) {

  CHECK( _valid_location( index ) );
  CHECK( _valid_color( color ) );

  w_colors[ index - from ] = color;

}

/* get color at location */
unsigned int TemplateSlot::get_color_at_location( int index ) const {

  CHECK( _valid_location( index ) );

  unsigned int color = w_colors[ index - from ];
  CHECK( _valid_color( color ) );

  return color;

}

/* create gappy pattern for this gist */
tr1::shared_ptr<GappyPattern> TemplateSlot::create_gappy_pattern() const {

  return tr1::shared_ptr<GappyPattern>( new GappyPattern( *this ) );

}

/* is this element templatic */
bool TemplateSlot::is_templatic() const {
  return false;
}

/* as string */
string TemplateSlot::as_string() const {

  string representation;

  for (int i = from; i <= to; i++) {

    MurmurHash2 hash;
    unsigned int pattern_hash_value = hash( get_color_pattern_from_color( get_color_at_location( i ) )->as_string() );
    
    representation.append("[");
    representation.append( boost::lexical_cast<std::string>( pattern_hash_value ) );
    representation.append("]");

  }

  return representation;

}

/* complete sampling procedure for the target word */
/* unset_color / set_color + registration management */
unsigned int TemplateSlot::sample_color( int index , bool do_register ) {
  
  /* CURRENT : in which cases is do_register relevant ? */

  /* remove color for current word (unregister) */
  {
    
    unsigned int current_color = get_color_at_location( index );
    CHECK( current_color != COLOR_NO_COLOR );

    /* decrement count for the current pattern */
    tr1::shared_ptr<GappyPattern> current_color_pattern = get_color_pattern_from_color( current_color );
    get_slot_type()->_decrement_pattern_count( *( current_color_pattern.get() ) );
    unsigned int current_color_pattern_length = current_color_pattern->get_number_of_words();
    
    /* effectively unset color for the target object */
    unset_color( index );
    
    /* increment count for shorter pattern */
    if  ( current_color_pattern->get_number_of_words() > 1 ) {
      tr1::shared_ptr<GappyPattern> new_color_pattern = get_color_pattern_from_color( current_color );
      get_slot_type()->_increment_pattern_count( *( new_color_pattern.get() ) );
    }
    
  }

  /* sample and set new color (register) */
  {
    
    bool new_color = false;
    unsigned int sampled_color = COLOR_NO_COLOR;
    
    /* resample color for the current word in the current slot */
    sampled_color = _sample_color( index );
    if ( sampled_color == COLOR_NO_COLOR ) {
      new_color = true;
    }
      
    CHECK ( new_color || sampled_color );
    
    /* actually set the color of the target word */
    tr1::shared_ptr<GappyPattern> gappy_pattern = set_color( index , new_color , sampled_color );
      
    /* update color (gappy pattern) counts */
    get_slot_type()->_increment_pattern_count( *( gappy_pattern.get() ) );

  }

  /* the target location must have been assigned a valid color */
  CHECK( get_color_at_location( index ) != COLOR_NO_COLOR );

}

/* sample next color given neutral state (no update) */
unsigned int TemplateSlot::_sample_color( int index ) const {

  CHECK( get_color_at_location( index ) == COLOR_NO_COLOR );

  vector<double> multinomial_probabilities;
  vector<unsigned int> multinomial_colors;

  bool new_color = false;
  bool has_free_color = false;
  unsigned int sampled_color = COLOR_NO_COLOR;

  /* compute probability of picking a new color */
  /* note: technically will always be true ! */
  if ( get_number_of_free_colors() ) {
    
    /* What does it mean to pick a new color ? */
    /* Means you're creating a brand new patter within this location, so the target word is surrounding by gaps (if needed) */

    has_free_color = true;

    /* create temporary gappy_pattern associated with the current word being assigned a new color */
    tr1::shared_ptr<GappyPattern> new_color_gappy_pattern( new GappyPattern( *this ) );
    new_color_gappy_pattern->add_word( index );

    double prob_new_color = _slot_type->_probability_new_color( *( new_color_gappy_pattern.get() ) );
    
    /* the probability to assign a new color / create a new pattern cannot be 0 */
    CHECK( prob_new_color );
    
    multinomial_probabilities.push_back( prob_new_color );
    multinomial_colors.push_back( COLOR_NO_COLOR );
    
  }
  
  /* compute probability of picking each of the existing colors */
  set<unsigned int> active_colors = get_colors();
  for ( set<unsigned int>::const_iterator color_iter = active_colors.begin() ; color_iter != active_colors.end() ; color_iter++ ) {
    
    unsigned int existing_color = *color_iter;
    
    /* get current gappy_pattern for this color */
    tr1::shared_ptr<GappyPattern> color_gappy_pattern = get_color_pattern_from_color( existing_color );
    
    /* compute probability of assigning this existing color to the current word */
    double existing_color_probability = _slot_type->_compute_probability_gappy_pattern_update( *( color_gappy_pattern.get() ) , index );
    multinomial_probabilities.push_back( existing_color_probability );
    multinomial_colors.push_back( existing_color );
    
  }
  
  /* sample color using multinomial distribution */
  unsigned int number_of_colors = multinomial_probabilities.size();
  vector<unsigned int> multinomial_sample( number_of_colors , 0 );
  gsl_ran_multinomial( _gsl_rng , number_of_colors , 1 , &multinomial_probabilities[0] , &multinomial_sample[0] );
  for ( vector<unsigned int>::const_iterator sample_iterator = multinomial_sample.begin();
	sample_iterator != multinomial_sample.end(); sample_iterator++ ) {
    
    if ( *sample_iterator ) {
      if ( has_free_color && ( sample_iterator == multinomial_sample.begin() ) ) {
	new_color = true;
	/* TODO: should we introduce a COLOR_NEW_COLOR color ? */
	sampled_color = COLOR_NO_COLOR;
      }
      else {
	new_color = false;
	sampled_color = multinomial_colors[ sample_iterator - multinomial_sample.begin() ];
      }
      break;
    }
    
  }

  return sampled_color;
  
}

/* registration procedure */
void TemplateSlot::_register() {

  /* TODO ? */

}

/* unregistration procedure */
void TemplateSlot::_unregister() {

  /* TODO ? */

}

/* compute the probability of this object */
double TemplateSlot::log_probability() {

  /* TODO - MCMC estimation of slot production ! */
  CHECK( 0 );

  /* we need a proposal distribution that ... */

  return 0.0;

}

/* extend this slot */
void TemplateSlot::extend( int index ) {

  CHECK( ( index == from - 1 ) || ( index == to + 1 ) );

  if ( index < from ) {
    from = index;
    w_colors.push_front(COLOR_NO_COLOR);
  }
  else {
    to = index;
    w_colors.push_back(COLOR_NO_COLOR);
  }

  /* add a new color so that each word can be associated with its own color/pattern */
  unsigned int color_id = to - from + 1;
  CHECK( _valid_color( color_id ) );
  free_colors.push( color_id );
  set_color( index , true );

}

/* shrink this slot */
void TemplateSlot::shrink( int index ) {

  CHECK( ( index == from ) || ( index == to ) );

  /* 1 - remove color at the target location */
  unset_color( index );
  
  /* 2 - shrink slot */
  if ( index == from ) {

    w_colors.pop_front();
    from++;

  }
  else {

    w_colors.pop_back();
    to--;

  }

  /* remove one color */
  free_colors.pop();

}

/* make sure we're dealing with a valid location in this slot */
bool TemplateSlot::_valid_location( int index ) const {

  return ( (index >= from) && (index <= to) );

}

/* make sure we're dealing with a valid color id */
bool TemplateSlot::_valid_color( unsigned int color_id ) const {
  
  return ( color_id >= 0 && color_id <= ( to - from + 1 ) ); 

}

/* get type */
GappyPatternProcess* const TemplateSlot::get_type() const {

  return _slot_type;

}

/* register coloring */
void TemplateSlot::register_coloring() {

  /* TODO: how do we do this ? global ? */
  
  /* assumes the coloring is not already registered */
  /* TODO: CHECK( ) */

  /* iterate over colors ? */
  


}

/* unregister coloring */
/* Note: this does not mean we are resetting the coloring ! */
void TemplateSlot::unregister_coloring() {

}
