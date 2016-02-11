package confusius.services.nlp;

import java.io.*;
import java.lang.*;

import edu.stanford.nlp.ling.*;
import edu.stanford.nlp.parser.lexparser.*;
import edu.stanford.nlp.trees.*;
import edu.stanford.nlp.objectbank.*;

public class NLPResource {

    protected static boolean bInitialized = false;
    protected static LexicalizedParser parser;
    protected static TreebankLanguagePack tlp;
    
    static {

	File dir1 = new File (".");
	File dir2 = new File ("..");
	try {
	    System.out.println ("Current dir : " + dir1.getCanonicalPath());
	    System.out.println ("Parent  dir : " + dir2.getCanonicalPath());
	}
	catch(Exception e) {
	    e.printStackTrace();
	}

	init();
    }


    protected static void init() {

	if ( bInitialized ) {
	    return;
	}

	parser = new LexicalizedParser("/home/ypetinot/disk1/project-working-copy/trunk/third-party/local/webapps/pos-tagger/WEB-INF/classes/stanford-parser/wsjPCFG.ser.gz");
	//parser = new LexicalizedParser("stanford-parser/wsjPCFG.ser.gz");
	parser.setOptionFlags(
			      "-headFinder", "edu.stanford.nlp.trees.ModCollinsHeadFinder",
			      "-outputFormat", "wordsAndTags",
			      "-outputFormatOptions", "markHeadNodes,removeTopBracket",
			      "-retainTMPSubcategories"
			      );
	
	tlp = parser.getOp().tlpParams.treebankLanguagePack();
		
	bInitialized = true; 

    }
    
}
