#include "tree.h"

/* constructor */
Category::Category( string name )
  :_label( name ) {

  /* nothing for now */

}

/* get label */
string Category::get_label() const {
  return _label;
}
