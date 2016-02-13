#include "document_content_distribution.h"

#include <google/protobuf/stubs/strutil.h>

/* default constructor */
DocumentContentDistribution::DocumentContentDistribution()
  : ContentDistribution()
{
  
  /* nothing */
  
}

/* constructor */
DocumentContentDistribution::DocumentContentDistribution(const HierarchyDocument& document, const string& smoothing_mode)
  : ContentDistribution(smoothing_mode)
{
  
  /* for now we only work off the description field */
  string description = document.get_description();

  /* tokenize description (reminder: we're already in the feature space, so nothing fancy needed here !) */
  vector<string> tokens;
  google::protobuf::SplitStringUsing(description," ",&tokens);

  for ( vector<string>::iterator iter = tokens.begin(); iter != tokens.end(); ++iter ) {
    increment_token_frequency(*iter,1);
    set_document_frequency(*iter,1);
  }
  
  /* set total number of documents */
  _number_of_documents = 1;

  /* set total number of tokens */
  _number_of_tokens = tokens.size();

}

/* destructor */
DocumentContentDistribution::~DocumentContentDistribution() {
  
  /* nothing */
  
} 
