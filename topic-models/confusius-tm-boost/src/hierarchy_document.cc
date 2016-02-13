#include "hierarchy_document.h"

/* default constructor - for deserialization purposes only */
HierarchyDocument::HierarchyDocument() {

  /* nothing */

}

/* constructor */
HierarchyDocument::HierarchyDocument(string url, string description)
  :_url(url),_description(description) {
 
  /* nothing */
 
}

/* url getter */
string HierarchyDocument::get_url() const {
  return _url;
}

/* description getter */
string HierarchyDocument::get_description() const {
  return _description;
}
