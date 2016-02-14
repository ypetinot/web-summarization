#ifndef __DOCUMENT_CONTENT_DISTRIBUTION__
#define __DOCUMENT_CONTENT_DISTRIBUTION__

#include "content_distribution.h"
#include "hierarchy_document.h"

class DocumentContentDistribution: public ContentDistribution {

 public:

  /* default constructor */
  DocumentContentDistribution();

  /* constructor */
  DocumentContentDistribution(const HierarchyDocument& document, const string& smoothing_mode);

  /* destructor */
  virtual ~DocumentContentDistribution();

 private:

};

#endif
