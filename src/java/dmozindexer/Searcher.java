/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package dmozindexer;


import org.apache.lucene.analysis.*;
import org.apache.lucene.analysis.standard.*;
import org.apache.lucene.search.*;
import org.apache.lucene.index.*;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.Document;
import org.apache.lucene.queryParser.*;

import java.io.*;


/**
 *
 * @author ypetinot
 */
public class Searcher {

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

	try {

	    org.apache.lucene.search.IndexSearcher searcher = new IndexSearcher(IndexReader.open(INDEX_DIR));
            System.err.println("Number of documents indexed: " + searcher.getIndexReader().numDocs());

	    Analyzer analyzer = new StandardAnalyzer();
            QueryParser parser = new QueryParser("description", analyzer);

	    BooleanQuery bquery = new BooleanQuery();

	    BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
	    String line;
	    while( (line = in.readLine()) != null ) {

		/* parse line */
		String[] fields = line.split("\t");

		if ( fields.length != 3 ) {
		    continue;
		}

		String token = fields[0].trim();

		if ( token.length() == 0 ) {
		    continue;
		}

		int df = Integer.parseInt(fields[1]);
		int corpus_count = Integer.parseInt(fields[2]);

		/* create query for this token */
		Query token_query = parser.parse(token);
		
		/* set boost factor for this term */
		//float boost_factor = (float)df/(float)corpus_count;
		float boost_factor = df;
		token_query.setBoost(boost_factor);

		/* add this query to our final query */
		bquery.add(token_query, BooleanClause.Occur.SHOULD);
		System.err.println("for: " + token + " --> added partial query: " + token_query.toString());

	    }


	    System.err.println("Searching for: " + bquery.toString());
	    Hits hits = searcher.search(bquery);
	    System.err.println("Number of matching documents = " + hits.length());
	    for (int i = 0; i < hits.length() && i < max_results; i++) {
		Document doc = hits.doc(i);
		System.out.println(doc.get("url") + "\t" + doc.get("title") + "\t" + doc.get("description") + "\t" +
				   doc.get("topic") + "\t" + hits.score(i));
	    }


	}
	catch (IOException e) {
	    System.out.println(" caught a " + e.getClass() +
			       "\n with message: " + e.getMessage());
	}
	catch (ParseException pe) {
	    System.out.println(" caught a " + pe.getClass() +
			       "\n with message: " + pe.getMessage());
	}

    } 
    
}
