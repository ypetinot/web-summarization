#ifndef __TREE_H__
#define __TREE_H__

#include <string>

using namespace std;

class Category {

 public:
  
  /* constructor */
  Category( string name );

  /* get label */
  string get_label() const;

 protected:
  
  /* category label */
  string _label;

};

#endif
