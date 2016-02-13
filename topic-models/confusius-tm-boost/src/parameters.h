#ifndef __PARAMETERS_H__
#define __PARAMETERS_H__

#include <gflags/gflags.h>

// model filename (input/output depending on requested action)
DECLARE_string(model_in);

// model filename (input/output depending on requested action)
DECLARE_string(model_out);

// action
DECLARE_string(action);

#endif
