#include "object.h"
#include "stringifiable.h"

#include <glog/logging.h>

/* get occurence count */
long CountableObject::count() const {

  /* Only one instance by default ? */
  return 1;

}
