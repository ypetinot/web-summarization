#ifndef __CONTENT_DISTRIBUTION_VISITOR__
#define __CONTENT_DISTRIBUTION_VISITOR__

#include "document_content_distribution.h"
#include "hierarchy.h"

#include <boost/graph/graph_traits.hpp>
#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/depth_first_search.hpp>
#include <boost/pending/integer_range.hpp>
#include <boost/pending/indirect_cmp.hpp>
#include <boost/tuple/tuple.hpp>
#include <boost/utility.hpp>

using namespace boost;

class ContentDistributionVisitor:public default_dfs_visitor {
  
 public:
  
  void discover_vertex(node_t u, const HierarchyTree& g) {
    VLOG(0) << "discovered vertex: " << u;
  }

  void finish_vertex(node_t u, const HierarchyTree& g) {
    
    VLOG(0) << "producing content distribution for node: " << u;
    
    vector< boost::shared_ptr<ContentDistribution> > content_distributions;
    
    VLOG(0) << "\tcompute content distribution for all the documents assigned to node " << u;

    unsigned n_documents = g[u].get_document_count();
    for (unsigned i=0; i<n_documents; i++) {
      
      /* get document */
      boost::shared_ptr<HierarchyDocument> document = g[u].get_document(i);
      
      /* generate content distribution for this document */
      boost::shared_ptr<ContentDistribution> dcd(new DocumentContentDistribution(*(document.get()), ""));
      
      /* Note: document content distributions don't have to be stored since */
      /* they aren't needed at later stages                                 */
      
      content_distributions.push_back(dcd);
      
    }

    VLOG(0) << "\tcollect content distritubtions for all children of node " << u;

    boost::graph_traits<HierarchyTree>::out_edge_iterator out_iter, out_end;
    for ( tie(out_iter, out_end) = boost::out_edges(u,g); out_iter != out_end; ++out_iter ) {
      
      /* get child node descriptor */
      node_t child_node = target(*out_iter,g);
      
      /* get content distribution property */
      boost::shared_ptr<ContentDistribution> cncd = g[child_node].get_content_distribution();
      
      content_distributions.push_back(cncd);
      
    }

    VLOG(0) << "\tcreate a new content distribution for node " << u;

    boost::shared_ptr<ContentDistribution> node_cd(new ContentDistribution());

    /* merge all the content distributions into one */
    for ( vector< boost::shared_ptr<ContentDistribution> >::iterator iter = content_distributions.begin(); iter != content_distributions.end(); ++iter ) {
      node_cd->merge( *((*iter).get()) );
    }

    /* store the merged content distribution in this node */
    const_cast<HierarchyTree&>(g)[u].set_content_distribution(node_cd);
    
  }
  
};

#endif
