/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package dmozindexer;


import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.Document;

import java.io.*;




/**
 *
 * @author ypetinot
 */
public class Indexer {

    private Indexer() {}
    
    static final File INDEX_DIR = new File("index");
    
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) {
            
      if (INDEX_DIR.exists()) {   
        System.out.println("Cannot save index to '" +INDEX_DIR+ "' directory, please delete it first");
        System.exit(1);
        }
        
    try {
      IndexWriter writer = new IndexWriter(INDEX_DIR, new StandardAnalyzer(), true);
      System.out.println("Indexing to directory '" +INDEX_DIR+ "'...");

    InputStreamReader isr = new InputStreamReader( System.in );
    BufferedReader stdin = new BufferedReader( isr );
    
    String input = null;
    while( (input = stdin.readLine()) != null ) {

	/* first split input line */
	String[] fields = input.split("\\t");
	if ( fields.length != 4 ) {
	    System.out.println("Skipping " + input + " ...");
	}

	String url = fields[0];
	String title = fields[1];
	String description = fields[2];
	String topic = fields[3];

	Document doc = new Document();
	doc.add(new Field("url", url, Field.Store.YES, Field.Index.UN_TOKENIZED));
	doc.add(new Field("title", title, Field.Store.YES, Field.Index.TOKENIZED));
	doc.add(new Field("description", description, Field.Store.YES, Field.Index.TOKENIZED));
	doc.add(new Field("topic", topic, Field.Store.YES, Field.Index.UN_TOKENIZED));
       
        writer.addDocument(doc);
          
    }
    
      System.out.println("Optimizing...");
      writer.optimize();
      writer.close();

    } catch (IOException e) {
      System.out.println(" caught a " + e.getClass() +
       "\n with message: " + e.getMessage());
    }
  } 
    
}
