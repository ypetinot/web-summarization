package edu.columbia.cs.nlp.webgraph.server.thrift;

import org.apache.thrift.server.TServer;
import org.apache.thrift.server.TServer.Args;
import org.apache.thrift.server.TSimpleServer;
import org.apache.thrift.server.TThreadPoolServer;
import org.apache.thrift.transport.TSSLTransportFactory;
import org.apache.thrift.transport.TServerSocket;
import org.apache.thrift.transport.TServerTransport;
import org.apache.thrift.transport.TSSLTransportFactory.TSSLTransportParameters;

import edu.columbia.cs.nlp.webgraph.*;

import java.util.HashMap;

public class WebGraphServer {

    /* run single/multi-threaded server ? */
    public static final boolean multi_threaded = true;
    
    /* non-blocking server ? */
    public static final boolean non_blocking = true;

    public static WebGraph handler;

    public static WebGraphService.Processor processor;

    public static void main(String [] args) {

	final int port = Integer.parseInt( args[ 0 ] );

	try {
	    handler = new WebGraph();
	    processor = new WebGraphService.Processor(handler);

	    Runnable simple = new Runnable() {
		    public void run() {
			simple( processor , port );
		    }
		};
	    new Thread(simple).start();

	    /*
	    Runnable secure = new Runnable() {
		    public void run() {
			secure( processor , port );
		    }
		};
		new Thread(secure).start();
	    */

	} catch (Exception x) {
	    x.printStackTrace();
	}
    }

    public static void simple( WebGraphService.Processor processor , int port ) {
	try {

	    // TODO : make port number configurable
	    TServerTransport serverTransport = non_blocking ?
		new TNonblockingServerSocket( port ) :
		new TServerSocket( port );
 
	    TServer server = multi_threaded ?
		( non_blocking ?
		  new TNonblockingServer(new TNonblockingServer.Args(serverTransport).processor(processor)) :
		  new TThreadPoolServer(new TThreadPoolServer.Args(serverTransport).processor(processor)) ) :
		new TSimpleServer(new Args(serverTransport).processor(processor));
	    
	    System.out.println("Starting server (multi-threaded: " + multi_threaded +
			       ") (non-blocking: " + non_blocking +
			       ") ...");
	    server.serve();

	} catch (Exception e) {
	    e.printStackTrace();
	}
    }

    public static void secure( WebGraphService.Processor processor , int port ) {
	try {

	    /*
	     * Use TSSLTransportParameters to setup the required SSL parameters. In this example
	     * we are setting the keystore and the keystore password. Other things like algorithms,
	     * cipher suites, client auth etc can be set. 
	     */
	    TSSLTransportParameters params = new TSSLTransportParameters();
	    // The Keystore contains the private key
	    params.setKeyStore("../../lib/java/test/.keystore", "thrift", null, null);

	    /*
	     * Use any of the TSSLTransportFactory to get a server transport with the appropriate
	     * SSL configuration. You can use the default settings if properties are set in the command line.
	     * Ex: -Djavax.net.ssl.keyStore=.keystore and -Djavax.net.ssl.keyStorePassword=thrift
	     * 
	     * Note: You need not explicitly call open(). The underlying server socket is bound on return
	     * from the factory class. 
	     */

	    // Transport
	    TServerTransport serverTransport = TSSLTransportFactory.getServerSocket(port, 0, null, params);

	    TServer server = multi_threaded ?
		new TThreadPoolServer(new TThreadPoolServer.Args(serverTransport).processor(processor)) :
		new TSimpleServer(new Args(serverTransport).processor(processor));
	    
	    System.out.println("Starting secure server...");
	    server.serve();

	} catch (Exception e) {
	    e.printStackTrace();
	}
    }
}
