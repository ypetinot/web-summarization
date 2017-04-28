#include "template.h"

#include "gist.h"
#include "parameters.h"

#include <boost/lexical_cast.hpp>
#include <glog/logging.h>

/* Design: this class can sample it's own state based on the underlying DP, however it is up to the controlling class to register the new state with the DP */

/* constructor ( with random initialization ) */
Template::Template( Gist* gist )
  :_gist(gist),_slots(_gist->length()),_slots_set(_gist->length(),0),_templatic_status(_gist->length(),TEMPLATIC_STATUS_NONE) {
  
  /* initialization */
  _init();

}

/* copy constructor */
Template::Template( const Template& t )
  :_gist(t._gist),_slots(_gist->length()),_slots_set(_gist->length(),0),_templatic_status(_gist->length(),TEMPLATIC_STATUS_NONE) {

  for ( unsigned int i = 0; i < _gist->length(); i++ ) {

    if ( t._templatic_status[ i ] == TEMPLATIC_STATUS_SLOT ) {

      tr1::shared_ptr<TemplateSlot> current_slot = t.get_slot_at_word_location ( i );
      tr1::shared_ptr<TemplateSlot> slot_replicate( new TemplateSlot( * ( current_slot.get() ) ) );

      /* make sure the slot is aligned with our current index */
      CHECK( slot_replicate->get_from() == i );

      for ( unsigned int j = slot_replicate->get_from(); j <= slot_replicate->get_to(); j++ ) {

	set_slot( j );
	
	CHECK( _templatic_status[ j ] == t._templatic_status[ j ] );
	CHECK( _slots_set[ j ] == t._slots_set[ j ] );

	/* we also increment i while we're at it (could have a single index ?) */
	i++;

      }

      /* correction */
      i--;

    }
    else if ( t._templatic_status[ i ] == TEMPLATIC_STATUS_TEMPLATIC ) {
      
      set_templatic( i );

    }
    else {

      /* should this happen ? */
      CHECK( 0 );

    }

    /* make sure we copied the template properly */
    CHECK( _templatic_status[ i ] == t._templatic_status[ i ] );
    CHECK( _slots_set[ i ] == t._slots_set[ i ] );

  }

}

/* init - random initialization */
void Template::_init() {
    
  bool in_slot = false;
  
  VLOG(INFO) << "Initializing template for " << _gist->get_url() << " ...";

  for ( unsigned int i = 0; i < _gist->length(); i++ ) {
    
    LOG(INFO) << "\t template initialization - position " << ( i + 1 ) << " / " << _gist->length() << " ...";

    /* flip a coin for every location in the gist */
    short int proposed_status = ( sample_uniform() > 0.5 ) ? TEMPLATIC_STATUS_TEMPLATIC : TEMPLATIC_STATUS_SLOT;
    
    /* create a lot location if needed */
    if ( proposed_status == TEMPLATIC_STATUS_SLOT ) {
      set_slot( i );
      CHECK( _slots_set[ i ] == 1 );
    }
    else {
      set_templatic( i );
    }
    
    LOG(INFO) << "\tCurrent template status for " << _gist->get_url() << " : " << as_string_log() << "\n";

  }

  /* Finally check the consistency of the template */
  CHECK( check_consistency() );
  
  LOG(INFO) << "Initialized template for " << _gist->get_url() << " : " << as_string_log() << "\n\n\n";

}

/* check structural consistency */
bool Template::check_consistency() const {
  
  for ( unsigned int i = 0; i < _gist->length(); i++ ) {
    
    if ( is_slot( i ) ) {
      
      tr1::shared_ptr<TemplateSlot> current_slot = get_slot_at_word_location( i );

      /* 1 - check consistency of slot */
      CHECK( current_slot->check_consistency() );
      
      /* 2 - check non-overlap */
      CHECK( current_slot->get_from() == i );
      i += ( current_slot->get_to() - current_slot->get_from() );

    }
    
  }

  return true;

}

/* flip templatic status at a specific location */
void Template::flip_templatic_status( unsigned int index ) {

  CHECK( check_consistency() );

  /* is this a templatic word */
  if ( is_templatic( index ) ) {
    set_slot( index );
  }
  else {
    set_templatic( index );
  }

  CHECK( check_consistency() );

}

/* get templatic status for a specific word */
int Template::get_templatic_status( unsigned int index ) const {
  CHECK( _valid_index( index ) );
  return _templatic_status[ index ];
}

/* get slot at word location */
const tr1::shared_ptr<TemplateSlot>& Template::get_slot_at_word_location( unsigned int i ) const {

  CHECK( _valid_index( i ) );
  CHECK( _slots_set[ i ] == 1 );

  return _slots[ i ];

}

/* get all slots in this template */
vector< tr1::shared_ptr<TemplateSlot> > Template::get_slots() const {

  return _slots;

}

#if 0
/* is the element at the target location templatic ? */
bool is_element_at_location_templatic( unsigned int i ) const {
  return _elements_templatic[ i ];
}
#endif

/* return gist/template data as string */
string Template::as_string() const {

  return _as_string( true , false , false );

}

/* return gist/template data as string (log content) */
string Template::as_string_log() const {

  return _as_string( true , true , true );

}

/* as_string with more options */
string Template::_as_string( bool abstract_slot_content , bool include_slot_type , bool include_slot_length ) const {

  vector< tr1::shared_ptr<TemplateSlot> >::const_iterator iter = _slots.begin();

  string representation = "";

  for ( unsigned int i = 0 ; i < _gist->length() ; i++ ) {
    
    if ( i > 0 ) {
      representation.append( " " );
    }
    
    if ( _templatic_status[ i ] == TEMPLATIC_STATUS_TEMPLATIC ) {
      
      long word_id = _gist->get_word( i );

      if ( word_id == WORD_ID_BOG ) {
	representation.append( "<BOG>" );
      }
      else if ( word_id == WORD_ID_EOG ) {
	representation.append( "<EOG>" );
      }
      else {
	representation.append( _gist->get_word_as_string( i ) );
      }

    }
    else if( _templatic_status[ i ] == TEMPLATIC_STATUS_SLOT ) {
      tr1::shared_ptr<TemplateSlot> current_slot = get_slot_at_word_location( i );
      CHECK( current_slot->check_consistency() );
      if ( abstract_slot_content ) {
	/* Note: right now the slot types are conditionally independent --> anonymous slot types */
	if ( include_slot_type ) {
	  representation.append( "[[ " + current_slot->get_type() + ( include_slot_length ? "-" + boost::lexical_cast<std::string>( current_slot->length() ) : "" ) + " ]]" );
	}
	else {
	  representation.append( "[[ slot ]]" );
	}
      }
      else {
	representation.append( current_slot->as_string() );
      }
      i += current_slot->length() - 1 ;
    }
    else {

      /* this should only happen in cases where we are about to update the templatic status at the current location */
      /* nothing */

    }

  }

  return representation;
  
}

/* tentatively (?) update template state */
tr1::shared_ptr<Template> Template::transition( unsigned int index , int state ) {

  /* 1 - make a copy of the current object ? */

}

/* return template string */
string Template::get_template_string() const {

  vector< short int >::const_iterator iter = _templatic_status.begin();

  string template_string;
  bool in_slot = false;

  while ( iter != _templatic_status.end() ) {

    string to_append;
    bool do_append = false;

    if ( !in_slot && !(*iter) ) {

      to_append = "[slot]";
      do_append = true;
      in_slot = true;

    } 
    else if ( !(*iter) ) {

      to_append = _gist->get_word_as_string( iter - _templatic_status.begin() );
      do_append = true;
      in_slot = false;

    }

    if ( do_append ) {
      template_string.append( to_append );
    }

    iter++;

  }

  return template_string;

}

/* truncate slot on its left side */
void Template::truncate_slot_left( tr1::shared_ptr<TemplateSlot> slot , unsigned int index ) {

  CHECK( slot->get_from() == index );

  return shrink_slot( index );

}

/* truncate slot on its right side */
void Template::truncate_slot_right( tr1::shared_ptr<TemplateSlot> slot , unsigned int index ) {

  CHECK( slot->get_to() == index );

  return shrink_slot( index );

}

/* remove slot at a specific location (does not split, shrinks from the side) */
void Template::shrink_slot( unsigned int index ) {
  
  CHECK( _valid_index( index ) );
  CHECK( check_consistency() );

  /* 1 - shrink slot at the target location */
  _slots[ index ]->shrink( index );

  /* 2 - deattach slot from the target location */
  _slots[ index ].reset();
  _slots_set[ index ] = 0;

  /* 3 - make target location templatic */
  set_templatic( index );

  CHECK( check_consistency() );

}

/* get slot at a specific location */
tr1::shared_ptr<TemplateSlot> Template::get_slot( unsigned int index ) const {

  CHECK( _valid_index( index ) && ( _slots_set[ index ] == 1 ) );

  return _slots[ index ];

}

/* check whether we have a slot status at a specific location */
bool Template::is_slot( unsigned int index ) const {

  CHECK( _valid_index( index ) );
  return ( (_templatic_status[ index ] == TEMPLATIC_STATUS_SLOT) && (_slots_set[ index ] == 1 ) );

}

/* check whether the target location is templatic */
bool Template::is_templatic( unsigned int index ) const {

  /* any location is either templatic or part of a slot */
  return ( ( ! is_slot( index ) ) && ( _slots_set[ index ] == 0 ) && ( _templatic_status[ index ] == TEMPLATIC_STATUS_TEMPLATIC ) );

}

/* set slot at a specific location */
/* --> contains all the logic for slot extensions */
void Template::set_slot( unsigned int index ) {

  CHECK( _valid_index( index ) );

  /* by default we don't have to create a new slot */
  bool do_create_slot = false;
  tr1::shared_ptr<TemplateSlot> target_slot;

  bool has_slot_left  = ( index > 0 && is_slot( index - 1 ) );
  bool has_slot_right = ( ( index < _gist->length() - 1 ) && is_slot( index + 1 ) );
  
  /* Create slot if needed */
  if ( ! has_slot_left && ! has_slot_right ) {
    /* we are in the middle of a templatic span or this is an unitialized location */
    do_create_slot = true;
  }

  if ( _templatic_status[ index ] == TEMPLATIC_STATUS_NONE ) {

    /* nothing to be done */
    do_create_slot = true;

  }
  else if ( _templatic_status[ index ] == TEMPLATIC_STATUS_TEMPLATIC ) {

    if ( ( has_slot_left && ! has_slot_right ) ) {

      /* we are at the left edge of a slot, all we have to do is extend that slot */
      target_slot = get_slot_at_word_location( index - 1 );
      target_slot->extend( index );

    }
    else if ( ! has_slot_left && has_slot_right ) {

      /* we are at the right edge of a slot, all we have to do is extend that slot */
      target_slot = get_slot_at_word_location( index + 1 );
      target_slot->extend( index );

    }
    else if ( ! has_slot_left && ! has_slot_right ) {

      /* we are in the middle of a template span - we will need a new slot here */
      do_create_slot = true;

    }
    else { /* slots on both sides */

      /* we extend the slot on the left while removing (shrinking ?) the slot on the right */
      tr1::shared_ptr<TemplateSlot> left_slot = get_slot_at_word_location( index - 1 );
      tr1::shared_ptr<TemplateSlot> right_slot = get_slot_at_word_location( index + 1 );

      unsigned int i = right_slot->get_from();
      do {
	
	/* should be coherent ? */
	//right_slot->shrink( i );
	set_templatic( i );

	/* 1 - extend left slot to current location */
	/* we need to preserve a gap of length 1 with the right slot to allow recursive calls */
	set_slot( i - 1 );
	//left_slot->extend( index );
	//copy_status( index , index - 1 , TEMPLATIC_STATUS_SLOT );
	CHECK( left_slot->get_to() == index );

	i++;

      }
      while( i <= right_slot->get_to() );

      set_slot( i - 1 );
	
      target_slot = left_slot;

    }
    
  }
  else {
    
    /* this should never happen */
    CHECK( 0 );
    
  }
  
  /* create a new slot if needed */
  if ( do_create_slot ) {
    tr1::shared_ptr<TemplateSlot> new_slot( new TemplateSlot( _gist , index , index ) );
    target_slot = new_slot; 
  }

  /* just in case this hasn't been done already */
  _templatic_status[ index ] = TEMPLATIC_STATUS_SLOT;
  _slots[ index ] = target_slot;
  _slots_set[ index ] = 1;

  CHECK( target_slot->check_consistency() );

}

/* set templatic (status) at a specific location */
void Template::set_templatic( unsigned int index ) {

  CHECK( _valid_index( index ) );

  if ( _templatic_status[ index ] == TEMPLATIC_STATUS_NONE ) {

    /* nothing to be done */

  }
  else if ( _templatic_status[ index ] == TEMPLATIC_STATUS_SLOT ) {

    /* we need to clean up the slot status first */
    tr1::shared_ptr<TemplateSlot> target_slot = get_slot_at_word_location( index );

    bool has_slot_left  = ( index > 0 && is_slot( index - 1 ) );
    bool has_slot_right = ( ( index < _gist->length() - 1 ) && is_slot( index + 1 ) );

    if ( ( has_slot_left && ! has_slot_right ) || ( ! has_slot_left && has_slot_right ) ) {

      /* we are at the edge of a slot, all we have to do is shrink that slot */
      target_slot->shrink( index );
      
      // /* simply truncate the slot on its left */
      // truncate_slot_left( target_slot , index );

      /* simply truncate the slot on its right */
      // truncate_slot_right( target_slot , index );

    }
    else if ( ! has_slot_left && ! has_slot_right ) {

      /* we are dealing with a length 1 slot - nothing to be done */
      /* assuming the structure has been previously unregistered  */

    }
    else { /* we are inside a slot */

      /* this is more complicated - we need to create two new slots and (re)initialize them */
    
      unsigned int from = target_slot->get_from();
      unsigned int to = target_slot->get_to();
    
      /* removing slot - we just need to "forget about it" */
      for ( unsigned int i = from ; i <= to ; i++ ) {
	target_slot->shrink( i );
	_templatic_status[ i ] = TEMPLATIC_STATUS_TEMPLATIC;
      }

      /* create new slot on the left */
      for ( unsigned int i = from ; i <= index - 1 ; i++ ) {
	set_slot( i );
      }
      
      /* create new slot on the right */
      for ( unsigned int i = index + 1 ; i <= to ; i++ ) {
	set_slot( i );
      }

    }

    /* unset any slot that might be assigned to this location */
    _slots_set[ index ] = 0;
  
  }
  else {

    /* this should never happen */
    CHECK( 0 );

  }

  /* finally set the templatic status at this location */
  _templatic_status[ index ] = TEMPLATIC_STATUS_TEMPLATIC;

}

/* copy (underlying) status - does not handle flipping logic */
void Template::copy_status( unsigned int index , unsigned int inherit_from_index , int status ) {

  CHECK( _valid_index( index ) );
  CHECK( _valid_index( inherit_from_index ) );
  CHECK( _templatic_status[ inherit_from_index ] == status );

  /* simply copy over all relevant variables from the reference location */
  _templatic_status[ index ] = _templatic_status[ inherit_from_index ];
  _slots[ index ] = _slots[ inherit_from_index ];
  _slots_set[ index ] = _slots_set[ inherit_from_index ];

}

/* check index validity */
bool Template::_valid_index( unsigned int index ) const {

  if ( ( index < 0 ) || ( index >= _slots.size() ) ) {
    return false;
  }

  return true;

}

// template --> slot_type --> slot_coloring
// 1 -> when sampling the template, we assume the slot type + slot_coloring is fixed
// 2 -> when sampling the slot type, we assume the template is fixed ... but what about the slot coloring ?
// A => B => C ... sample from P(B|A,C) ... but ...

// P( s_t | template )
// p( template | s_t ) = p ( s_t | template ) * p( template ) / p( s_t )

/* resample all slot types for the target gist's template */
/* gibbs-sampling: other variables (--> ?) remain unchanged*/
/* TODO: review gibbs-sampling for trees ... */
/* TODO: is sampling done according to a tree ? */
void Template::sample_slot_types_and_register() {
  
  for (unsigned int i = 0; i<_slots.size(); i++) {

    if ( _templatic_status[ i ] == TEMPLATIC_STATUS_SLOT ) {

      tr1::shared_ptr<TemplateSlot> current_slot = _slots[ i ];

      /* 1 - sample slot type */
      /* --> implies a coloring resampling for color types other than the current type */
      current_slot->sample_full( true );

      /* TODO: better slot iteration ? */
      i += current_slot->length();

    }

  }

}
