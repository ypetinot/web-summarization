package confusius.services.nlp;

import java.io.*;
import java.lang.System;
import java.util.*;

import edu.stanford.nlp.process.*;
import edu.stanford.nlp.util.*;
import edu.stanford.nlp.ling.*;
import edu.stanford.nlp.objectbank.*;

import org.osoa.sca.annotations.Service;
import org.osoa.sca.annotations.Reference;

@Service(SentenceChunker.class)
public class SentenceChunkerImpl extends NLPResource implements SentenceChunker {

    private static DocumentPreprocessor preprocessor;
    private static Function<List<HasWord>, List<HasWord>> escaper;
    private static String sentenceDelimiter;
    private static int tagDelimiter;

    static {


      	NLPResource.init();

	TokenizerFactory<? extends HasWord> tokenizerFactory = null;
	preprocessor = new DocumentPreprocessor();
	boolean tokenized = false; // whether or not the input file has already been tokenized
	escaper = null;
	tagDelimiter = -1;
	sentenceDelimiter = null; //"\n";
	preprocessor.setTokenizerFactory(NLPResource.tlp.getTokenizerFactory());
	preprocessor.setSentenceFinalPuncWords(NLPResource.tlp.sentenceFinalPunctuationWords());
	preprocessor.setEncoding(NLPResource.parser.getOp().tlpParams.getInputEncoding());

    }

    public String chunk(String text) {

	StringReader inputReader = new StringReader(text);
        StringWriter stringWriter = new StringWriter();

	/* extract all sentences from input */
	List<List<? extends HasWord>> document = preprocessor.getSentencesFromText(inputReader, escaper, sentenceDelimiter, tagDelimiter);
	
	int num = 0;
	for (List<? extends HasWord> sentence : document) {
	 
	    num++;
	    
	    if ( sentence.size() == 0 ) {
		continue;
	    }

	    stringWriter.write( sentence + "\n");

	}

	return stringWriter.toString();

    }


}
