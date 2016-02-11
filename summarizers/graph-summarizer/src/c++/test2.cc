#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/graphviz.hpp>

struct Vertex{
  std::string name;
  size_t times_visited;
  float value;
  bool terminal_node;
  bool root_node;
};

struct Edge{
  float probability;
};

//Some typedefs for simplicity
typedef boost::adjacency_list<boost::listS, boost::vecS, boost::directedS, Vertex, Edge> directed_graph_t;

typedef boost::graph_traits<directed_graph_t>::vertex_descriptor vertex_t;
typedef boost::graph_traits<directed_graph_t>::edge_descriptor edge_t;

std::ofstream outf("test.dot");
boost::dynamic_properties dp;
dp.property("label", boost::get(&Vertex::name, std::test));
dp.property("node_id", boost::get(boost::vertex_index, test));
dp.property("label", boost::get(&Edge::probability, test));
write_graphviz_dp(outf, test, dp);
