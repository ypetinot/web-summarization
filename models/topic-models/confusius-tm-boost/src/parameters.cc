#include "parameters.h"

// model filename (input/output depending on requested action)
DEFINE_string(model_in,
	      "",
	      "model file");

// model filename (input/output depending on requested action)
DEFINE_string(model_out,
	      "",
	      "model file");

// action
DEFINE_string(action,
	      "",
	      "action to perform on the document hierarchy");

