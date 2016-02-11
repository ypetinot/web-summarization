package confusius.services.nlp;

import java.io.*;
import java.lang.System;
import java.util.*;

import edu.stanford.nlp.ling.*;
import edu.stanford.nlp.parser.lexparser.*;
import edu.stanford.nlp.trees.*;
import edu.stanford.nlp.objectbank.*;

import org.osoa.sca.annotations.Service;
import org.osoa.sca.annotations.Reference;

@Service(PartOfSpeechTagger.class)
public class PartOfSpeechTaggerImpl extends NLPResource implements PartOfSpeechTagger {

    protected static TreePrint treeprinter;

    static {
	NLPResource.init();
	treeprinter = NLPResource.parser.getTreePrint();
    }

    public String parse(String text) {

	StringWriter stringWriter = new StringWriter();
	
	/* parse */
	boolean success = parser.parse(text);
	    
	if ( success ) {
		
	    /* get the best parse */
	    Tree tree = parser.getBestParse();
	    
	    /* process tree */
	    Tree filtered_tree = tree;
	    
	    /* dump tree */
	    treeprinter.setPrintWriter(new PrintWriter(stringWriter));
	    treeprinter.printTree(filtered_tree);
		
	}
	
	/* return content of string writer */
	return stringWriter.toString();
	
    }
    
}
