#include <assert.h>
#include "hierarchy_node.h"

#include <glog/logging.h>

HierarchyNode::HierarchyNode() {

  /* nothing */

}

/* destructor */
HierarchyNode::~HierarchyNode() {

  /* nothing */

}

/* name setter */
void HierarchyNode::set_name(const string& category_name) {
  _name = category_name;
}

/* name getter */
const string& HierarchyNode::get_name() const {  
  return _name;
}

/* attach document to this node */    
void HierarchyNode::attach_document(HierarchyDocument* document) {

  /* TODO: add a check to make sure this url is not already listed under the parent node */

  /* add document to this category node */
  _documents.push_back( boost::shared_ptr<HierarchyDocument>(document) );

}

/* get number of documents under this node */
unsigned HierarchyNode::get_document_count() const {
  return _documents.size();
}

/* get a specific document given its index */
boost::shared_ptr<HierarchyDocument> HierarchyNode::get_document(unsigned index) const {
  assert(index<=_documents.size()-1);
  return _documents[index];
}

/* content distribution getter */
boost::shared_ptr<ContentDistribution> HierarchyNode::get_content_distribution() const {
  return _content_distribution;
}

/* content distribution setter */
void HierarchyNode::set_content_distribution(boost::shared_ptr<ContentDistribution> cd) {
  _content_distribution = cd;
}
