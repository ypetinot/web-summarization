#ifndef __HIERARCHY_H__
#define __HIERARCHY_H__

#include <string>

#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/depth_first_search.hpp>
#include <glog/logging.h>
#include <google/dense_hash_map>

#include "hierarchy_node.h"

using namespace boost;
using namespace std;

//Define the graph
//typedef boost::adjacency_list<boost::listS, boost::vecS, boost::directedS, HierarchyNode> HierarchyTree;
typedef boost::adjacency_list<boost::listS, boost::vecS, boost::bidirectionalS, HierarchyNode> HierarchyTree;

//Some typedefs for simplicity
typedef boost::graph_traits<HierarchyTree>::vertex_descriptor node_t;
typedef boost::graph_traits<HierarchyTree>::edge_descriptor edge_t;

class ContentDistributionVisitor;

class Hierarchy {
  
 public:

  /* build hierarchy from scratch */
  static Hierarchy* build(const string& filename);

  /* load serialized model */
  static Hierarchy* load(const string& filename);
  
  /* serialize model */
  void serialize(const string& filename) const;  
  
  void dump_nodes() const;

  /* dump this hierarchy */
  void dump() const;

  /* get root node */
  HierarchyNode* get_category_node(const string& category_name) const;

  /* depth first search (for now just reproduce Boost Graph API) */
  void depth_first_search(const ContentDistributionVisitor& visitor);

 protected:
  
  /* default constructor - only used for deserialization purposes */
  Hierarchy();

  /* init */
  void init();

  /* retrieve internal node id for a node */
  //  node_t get_internal_node_id(const HierarchyNode& parent) const;
  node_t get_internal_node_id(const string& parent_node_name) const;

  /* hierarchy tree */
  HierarchyTree _hierarchy_tree;

  /* internal node index */
  google::dense_hash_map<string, node_t> _internal_node_index;

 private:

  /* hierarchy name */
  string _name;

  /* set parent node */
  void set_parent_node(const string& parent_node_name, const string& child_node_name);
  
  /* add category node */
  HierarchyNode* add_category_node(const string& category_name);
  
  /* add entry node */
  void attach_document(const HierarchyNode& parent, const HierarchyDocument& document);

  friend class boost::serialization::access;
  template<class Archive>
    void serialize(Archive & ar, const unsigned int version)
    {
      ar & boost::serialization::make_nvp("_hierarchy_name", _name);
      //      ar & boost::serialization::make_nvp("_hierarchy_tree", _hierarchy_tree);
      //ar & boost::serialization::make_nvp("_internal_node_index", _internal_node_index);
    }

};

#endif
