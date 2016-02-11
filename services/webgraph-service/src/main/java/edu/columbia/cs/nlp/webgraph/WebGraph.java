package edu.columbia.cs.nlp.webgraph;

import it.unimi.dsi.big.webgraph.*;
import it.unimi.dsi.big.webgraph.BVGraph;
import it.unimi.dsi.logging.ProgressLogger;
import java.io.PrintStream;
import java.util.LinkedList;
import java.util.List;

public class WebGraph implements edu.columbia.cs.nlp.webgraph.server.thrift.WebGraphService.Iface {

    // http://en.wikipedia.org/wiki/Singleton_pattern#Initialization-on-demand_holder_idiom
    private static class WebGraphHolder {

	// TODO : turn baseName into a parameter => how do we handle the fact that it is static ?
	private static final String baseName = "/local/nlp/ypetinot/data/web-data-commons-transposed/2014/webgraph.trans";
	private static final it.unimi.dsi.big.webgraph.BVGraph graph = load_graph();

	private static it.unimi.dsi.big.webgraph.BVGraph load_graph() {

	    it.unimi.dsi.big.webgraph.BVGraph graph = null;

	    try {
		System.out.println( "Loading WebGraph : " + baseName );
		graph = it.unimi.dsi.big.webgraph.BVGraph.loadMapped( baseName , new ProgressLogger() );
		System.out.println( "Done loading WebGraph !" );
	    }
	    catch( java.io.IOException ex ) {
		System.out.println( "Unable to load WebGraph: " + ex );
	    }

	    return graph;

	}


    }

    public List<Long> get_linking_nodes( long node_id , long max ) {

	System.out.println( "Requesting incoming links for : " + node_id );

	List<Long> output = new LinkedList<Long>();
	
	// get list of incoming links for target node id
	try {

	    // Note : remember that we are working off an inverted graph
	    LazyLongIterator linking_nodes_id_iterator = WebGraphHolder.graph.successors( node_id );
	    
	    // 3 - map successor node ids to URLs
	    System.out.println( "Iterating over incoming links for : " + node_id );
	    long link_count = 0;
	    while ( true ) {
		
		// TODO : could I write this in a cleaner way ? This is the best I can come up with currently ...
		Long linking_node_id = linking_nodes_id_iterator.nextLong();
		if ( linking_node_id < 0 ) {
		    System.out.println( "We're done ..." );
		    break;
		}
		
		link_count++;

		System.out.println( "Found linking node for <" + node_id + "> : <" + link_count + "|" + linking_node_id + ">" );
		output.add( linking_node_id );

		if ( max > 0 && link_count >= max ) {
		    break;
		}

	    
	    }

	}
	catch( Exception ex ) {
	    System.out.println( "An exception occurred while requestion incoming links (" + node_id + ") ..." );
	    ex.printStackTrace(new PrintStream(System.err));
	}

	return output;

    }

}
