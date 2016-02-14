#include "hierarchy.h"

#include "content_distribution_visitor.h"
#include "serialization.h"

#include <fstream>
#include <iostream>
#include <tr1/memory>
#include <vector>
#include <string>

#include <boost/config.hpp>
#include <boost/graph/depth_first_search.hpp>
#include <boost/tuple/tuple.hpp>

#include <google/protobuf/stubs/strutil.h>

using namespace std;
using namespace boost;

const static string _empty_node_key = "__EMPTY_NODE_KEY__";

BOOST_CLASS_VERSION(Hierarchy, 1)

Hierarchy::Hierarchy()
  :_hierarchy_tree() {
  /* init instance */
  init();
}

void Hierarchy::init() {

  /* for testing purposes */
  //_name = "confusius";

  /* TODO: make this a constant ? */
  _internal_node_index.set_empty_key(_empty_node_key);
  _internal_node_index.clear();

}

/* load serialized model */
Hierarchy* Hierarchy::load(const string& filename) {

  VLOG(1) << "loading model from file: " << filename;

  /* create an empty Hierarchy instance */
  Hierarchy* hierarchy = new Hierarchy();
  Hierarchy& hierarchy_ref = *hierarchy;

  std::ifstream ifs(filename.c_str(), std::ios::binary);
  boost::archive::text_iarchive ia(ifs);
  //boost::archive::xml_iarchive ia(ifs);
  //boost::archive::binary_iarchive ia(ifs);
  ia >> BOOST_SERIALIZATION_NVP(hierarchy_ref);

  ifs.close();

  return hierarchy;

}

/* serialize model */
void Hierarchy::serialize(const string& filename) const {

  const Hierarchy& hierarchy = *this;

  std::ofstream ofs( (filename).c_str(), std::ios::binary);
  boost::archive::text_oarchive oa(ofs);
  //boost::archive::xml_oarchive oa(ofs);
  //boost::archive::binary_oarchive oa(ofs);
  oa & BOOST_SERIALIZATION_NVP(hierarchy);

#if 0
  std::stringstream ofs;
  boost::archive::text_oarchive oa(ofs);
  oa & BOOST_SERIALIZATION_NVP(hierarchy);

  Hierarchy h;
  boost::archive::text_iarchive ia(ofs);
  ia >> BOOST_SERIALIZATION_NVP(h);

  std::ofstream ofs2( (filename).c_str(), std::ios::binary);
  boost::archive::binary_oarchive oa2(ofs2);
  oa2 & BOOST_SERIALIZATION_NVP(h);
#endif

}

/* retrieve internal node id for a node */
node_t Hierarchy::get_internal_node_id(const string& node_name) const {

  VLOG(1) << "retrieving internal node id for node " << node_name;

  google::dense_hash_map<string, node_t>::const_iterator iter = _internal_node_index.find(node_name);
  assert(iter != _internal_node_index.end());
  node_t inid = (*iter).second;

  VLOG(1) << "internal node id for node " << node_name << " is " << inid;

  return inid;

}

HierarchyNode* Hierarchy::add_category_node(const string& category_name) {

  VLOG(1) << "creating category node: " << category_name;

  // we need to create a new node
  node_t u = boost::add_vertex(_hierarchy_tree);
  
  /* set node's name */
  _hierarchy_tree[u].set_name(category_name);

  /* update name to node mapping */
  /* TODO: is there a better way of achieving this indexing ? */
  _internal_node_index[category_name] = u;

  VLOG(1) << "internal node id for " << category_name << " is " << u;

  HierarchyNode* result = &(_hierarchy_tree[u]);

  return result;

}

/* get category node */
HierarchyNode* Hierarchy::get_category_node(const string& category_name) const {

  VLOG(1) << "fetching category node for: " << category_name;

  google::dense_hash_map<string, node_t>::const_iterator iter = _internal_node_index.find(category_name);
  if ( iter == _internal_node_index.end() ) {
    VLOG(1) << "category node does not exist: " << category_name;
    return NULL;
  }

  node_t internal_node = get_internal_node_id(category_name);

  return const_cast<HierarchyNode*>(&(_hierarchy_tree[internal_node]));

}

/* set parent node */
void Hierarchy::set_parent_node(const string& parent_node_name, const string& child_node_name) {

  VLOG(1) << "creating edge between " << parent_node_name << " and " << child_node_name;

  // Create an edge conecting the parent node and the new node
  node_t from = get_internal_node_id(parent_node_name);
  node_t to   = get_internal_node_id(child_node_name);

  edge_t e; bool b;
  boost::tie(e,b) = boost::add_edge(from,to,_hierarchy_tree);

  VLOG(1) << "done creating edge between " << parent_node_name << " and " << child_node_name;

}

Hierarchy* Hierarchy::build(const string& filename) {
  
  VLOG(0) << "building hierarchy from file: " << filename;

  istream* input_stream = &cin;
  bool release_istream = false;
  filebuf fb;
  
  /* open filename or STDIN if filename is empty */
  if ( filename.length() ) {
    fb.open (filename.c_str(), ios::in);
    input_stream = new istream(&fb);
    release_istream = true;
  }

  /* create a new Hierarchy instance */
  Hierarchy* hierarchy = new Hierarchy();

  /* read one line after the other */
  /* expected format: <url> \t <title> <\t> <description> \t <category> */
  string line;
  while( getline(*input_stream, line) ) {

    /* parse the current line */
    vector<string> fields;
    google::protobuf::SplitStringUsing(line,"\t",&fields);

    /* is this the last line */
    if ( ! line.length() || fields.size() < 4 ) {
      continue;
    }

    const string& url = fields[0];
    const string& title = fields[1];
    const string& description = fields[2];
    const string& category = fields[3];

    VLOG(2) << "parsed input line: " << url << " | " << title << " | " << description << " | " << category;

    /* generate full list of topics */
    vector<string> topics;
    google::protobuf::SplitStringUsing(category,"/",&topics);

    /* create path in graph (i.e. add all the edges along the path) */
    string current;
    string parent_node_name;
    for(unsigned i=0; i<topics.size(); i++) {

      if ( current.length() != 0 ) {
	current += "/";
      }      
      current += topics[i];
      
      assert( current.length() );

      /* check to see if this node exists */
      HierarchyNode* current_node = hierarchy->get_category_node(current);
      if ( current_node == NULL ) {
	
	/* create this category node */
	current_node = hierarchy->add_category_node(current);
	assert(current_node);

	if ( parent_node_name.length() ) {
	  hierarchy->set_parent_node(parent_node_name,current);
	}
	
      }
   
      parent_node_name = current;

    }

    /* create document and attach it to its parent category */
    HierarchyDocument* document = new HierarchyDocument(url, description); 
    HierarchyNode* parent_node = hierarchy->get_category_node(parent_node_name);
    parent_node->attach_document(document);

  }

  /* release istream if input was coming from a file */
  if ( release_istream ) {
    delete input_stream;
  }
  
  // needed as long as we rely on protobuf for parsing
  google::protobuf::ShutdownProtobufLibrary();

  return hierarchy;

}

void Hierarchy::dump_nodes() const {

  graph_traits < HierarchyTree >::vertex_iterator i, end;
  graph_traits < HierarchyTree >::adjacency_iterator ai, ai2, a_end;
  property_map < HierarchyTree, vertex_index_t >::type
    index_map = get(vertex_index, _hierarchy_tree);
  
  for (tie(i, end) = vertices(_hierarchy_tree); i != end; ++i) {
    string node_name = _hierarchy_tree[*i].get_name();
    std::cout << node_name << " " << node_name.length() << std::endl;
  }

  std::cout << std::endl;

}

void Hierarchy::dump() const {

  graph_traits < HierarchyTree >::vertex_iterator i, end;
  graph_traits < HierarchyTree >::adjacency_iterator ai, ai2, a_end;
  property_map < HierarchyTree, vertex_index_t >::type
    index_map = get(vertex_index, _hierarchy_tree);
  
  for (tie(i, end) = vertices(_hierarchy_tree); i != end; ++i) {
    std::cout << _hierarchy_tree[*i].get_name();
    tie(ai, a_end) = adjacent_vertices(*i, _hierarchy_tree);
    ai2 = ai;
    if (ai == a_end) {
      std::cout << " has no children" << std::endl;
      unsigned n_documents = _hierarchy_tree[*i].get_document_count();
      if ( n_documents > 0 ) {
	for (unsigned j=0; j<n_documents; j++) {
	  std::cout << "\t" << _hierarchy_tree[*i].get_document(j)->get_url() << std::endl;
	}
      }
    }
    else {
      std::cout << " is the parent of ";
      for (; ai != a_end; ++ai) {
	std::cout << _hierarchy_tree[*ai].get_name();
	if (boost::next(ai) != a_end)
	  std::cout << ", ";
      }
    }
    std::cout << std::endl;
  }

}

/* depth first search (for now just reproduce Boost Graph API) */
void Hierarchy::depth_first_search(const ContentDistributionVisitor& v) {

  /* retrieve vertex descriptor for the the root of the hierarchy */
  const int nVertices =boost::num_vertices(_hierarchy_tree); 
  std::vector<boost::default_color_type> colors(nVertices); 
  node_t root = get_internal_node_id("Top");

  /* forward call to Boost Graph instance */
  boost::depth_first_search(_hierarchy_tree, v, &colors[0], root);
  //  boost::depth_first_search(_hierarchy_tree, visitor(v));

}
