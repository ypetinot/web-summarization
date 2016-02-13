#ifndef __HIERARCHY_NODE_H__
#define __HIERARCHY_NODE_H__

#include "content_distribution.h"
#include "hierarchy_document.h"

#include <tr1/memory>
#include <string>
#include <vector>

using namespace std;

class HierarchyNode {

 public:

  /* default constructor */
  HierarchyNode();

  /* destructor */
  ~HierarchyNode();

  /* name getter */
  const string& get_name() const;

  /* name setter */
  void set_name(const string& category_name);

  /* attach document to this node */    
  void attach_document(HierarchyDocument* document);

  /* get number of documents under this node */
  unsigned get_document_count() const;

  /* get a specific document given its index */
  boost::shared_ptr<HierarchyDocument> get_document(unsigned index) const;

  /* content distribution getter */
  boost::shared_ptr<ContentDistribution> get_content_distribution() const;

  /* content distribution setter */
  void set_content_distribution(boost::shared_ptr<ContentDistribution> cd);

 protected:
  
  /* node name */
  string _name;

  /* node content distribution (for now only one modality) */
  boost::shared_ptr<ContentDistribution> _content_distribution;

  /* list of documents assigned to this node */
  vector< boost::shared_ptr<HierarchyDocument> > _documents;

 private:

  friend class boost::serialization::access;
  template<class Archive>
    void serialize(Archive & ar, const unsigned int version)
    {
      ar & boost::serialization::make_nvp("_name", _name);
      ar & boost::serialization::make_nvp("_documents", _documents);
      ar & boost::serialization::make_nvp("_content_distribution", _content_distribution);
    }

};

#endif
