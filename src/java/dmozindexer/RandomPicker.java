/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */


/* TODO: define standard pipeline, so that random picker is just one of the many options for the IR stage ! */

package dmozindexer;


import org.apache.lucene.analysis.*;
import org.apache.lucene.analysis.standard.*;
import org.apache.lucene.search.*;
import org.apache.lucene.index.*;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.Document;
import org.apache.lucene.queryParser.*;

import java.util.Random;

import java.io.*;



/**
 *
 * @author ypetinot
 */
public class RandomPicker {

    static final File INDEX_DIR = new File("index");
    
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) {
            
	if (!INDEX_DIR.exists()) {   
	    System.out.println(INDEX_DIR + "' directory doesn't exist, please create index first");
	    System.exit(1);
        }
	else if ( args.length != 1 ) {
	    System.out.print("Usage: max_results");
	    System.exit(1);
	}

	int max_results = Integer.parseInt(args[0]);

	Random generator = new Random();

	try {

	    IndexReader reader = IndexReader.open(INDEX_DIR);

	    int number_of_documents = reader.numDocs();

            System.err.println("Number of documents indexed: " + number_of_documents);

	    for (int i=0; i<max_results; i++) {

		/* randomly pick one id between 1 and number_of_documents */
		int random_id = 1 + generator.nextInt(number_of_documents-1);

		/* for now */
		int score = 0;

		/* get the document corresponding to the picked id and print its content to stdout */
		Document doc = reader.document(random_id);
		System.out.println(doc.get("url") + "\t" + doc.get("title") + "\t" + doc.get("description") + "\t" +
				   doc.get("topic") + "\t" + score);
	    }


	}
	catch (IOException e) {
	    System.out.println(" caught a " + e.getClass() +
			       "\n with message: " + e.getMessage());
	}

    } 
    
}
