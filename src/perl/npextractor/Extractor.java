package npextractor;

import java.io.*;
import edu.stanford.nlp.parser.lexparser.LexicalizedParser;
import edu.stanford.nlp.trees.PennTreebankLanguagePack;
import edu.stanford.nlp.trees.Tree;
import edu.stanford.nlp.trees.TreePrint;

public class Extractor {

    static LexicalizedParser parser;
    static TreePrint tp = new TreePrint("oneline,", new PennTreebankLanguagePack());
    static PrintWriter pwSysOut = new PrintWriter(System.out, true);

    private static void init(String PARSER_PATH) {
	System.getProperties().setProperty("edu.stanford.nlp.SerializedLexicalizedParser", PARSER_PATH);
	parser = new LexicalizedParser();
    }
    
    public static void main(String[] argv) {

	if ( argv.length != 1 ) {
	    System.err.println("usage: java npextractor.Extractor PARSER_PATH");
	    System.exit(1);
	}
	
	String parser_path = argv[0];
	init(parser_path);

	try {

	    /* now read line by line, each line is processed independently */
	    InputStreamReader isr = new InputStreamReader( System.in );
	    BufferedReader stdin = new BufferedReader( isr );
	    
	    String input = null;
	    while( (input = stdin.readLine()) != null ) {
		
		parser.parse(input);
		Tree best = parser.getBestParse();

		/* now keep only NPs */
		tp.printTree(best, pwSysOut);

	    }

	} catch (IOException e) {
	    System.out.println(" caught a " + e.getClass() +
			       "\n with message: " + e.getMessage());
	}
	

    }

}
