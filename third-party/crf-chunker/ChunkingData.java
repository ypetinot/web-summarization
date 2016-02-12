/*
    Copyright (C) 2006, Xuan-Hieu Phan
    
    Email:	hieuxuan@ecei.tohoku.ac.jp
		pxhieu@gmail.com
    URL:	http://www.hori.ecei.tohoku.ac.jp/~hieuxuan
    
    Graduate School of Information Sciences,
    Tohoku University
*/

package crf.chunker;

import java.io.*;
import java.util.*;

public class ChunkingData {
    List data = null;
    
    // each sentence on one line
    public void readData(String dataFile) {
	if (data != null) {
	    data.clear();
	} else {
	    data = new ArrayList();
	}
	
	// open data file
	BufferedReader fin = null;
	
	try {
	    fin = new BufferedReader(new FileReader(dataFile));	
	    
	    System.out.println("Reading input data ...");
	    
	    String line = null;
	    // start to read sentences => sequences
	    while ((line = fin.readLine()) != null) {
		StringTokenizer strTok = new StringTokenizer(line, " \t\r\n");
		
		if (strTok.countTokens() == 0) {
		    // skip this blank line
		    continue;
		}
		
		// create new data sequence
		List seq = new ArrayList();
		
		while (strTok.hasMoreTokens()) {
		    Observation obsr = new Observation();
		    obsr.originalData = strTok.nextToken();
		    seq.add(obsr);
		}
		
		data.add(seq);
	    }
	    
	    System.out.println("Reading input data (" + Integer.toString(data.size()) + 
			" sequences) completed!");
	    
	} catch (IOException e) {
	    System.out.println("Couldn't open data file" + dataFile);
	    return;
	}
    }
    
    // write output, each sentence on a line
    // <word1>/<postag1>/<chunk tag1>  <word2>/<postag2>/<chunk tag2> ...
    public void writeData(Map lbInt2Str, String outputFile) {
	if (data == null) {
	    return;
	}
	
	PrintWriter fout = null;
	
	try { 
	    fout = new PrintWriter(new FileWriter(outputFile));
	
	    // main loop for writing
	    for (int i = 0; i < data.size(); i++) {
		List seq = (List)data.get(i);
		for (int j = 0; j < seq.size(); j++) {
		    Observation obsr = (Observation)seq.get(j);
		    fout.print(obsr.toString(lbInt2Str) + " ");
		}
		fout.println();
	    }
	
	    fout.close();
	    
	} catch(IOException e) {
	    System.out.println("Couldn't create file: " + outputFile);
	    return;
	}
    }
    
    // context predicate generation for each position
    public void cpGen(Map cpStr2Int, List seq, int i) {
	int seqLen = seq.size();
	
	if (i < 0 || i > seqLen - 1) {
	    return;
	}	
	
	String[][] tokens = new String[seqLen][2];
	int j;
	for (j = 0; j < seqLen; j++) {
	    StringTokenizer strTok = new StringTokenizer(((Observation)seq.get(j)).originalData, 
			Option.inputSeparator);
	    tokens[j][0] = strTok.nextToken().toLowerCase();
	    tokens[j][1] = strTok.nextToken().toLowerCase();
	}
	
	List tempCps = new ArrayList();    
	
	// single word
	for (j = -2; j <= 2; j++) {
	    if (i + j >= 0 && i + j < seqLen) {
		// 1 = w:
		String cp = "1:";
		cp += Integer.toString(j) + ":" + tokens[i + j][0];
		tempCps.add(cp);
	    }
	}
	
	// two consecutive words
	for (j = -1; j <= 0; j++) {
	    if (i + j >= 0 && i + j + 1 < seqLen) {
		// 2 = ww:
		String cp = "2:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + ":" +
			    tokens[i + j][0] + ":" + tokens[i + j + 1][0];
		tempCps.add(cp);
	    }
	}
	
	// single POS tag
	for (j = -2; j <= 2; j++) {
	    if (i + j >= 0 && i + j < seqLen) {
		// 3 = p:
		String cp = "3:";
		cp += Integer.toString(j) + ":" + tokens[i + j][1];
		tempCps.add(cp);
	    }
	}
	
	// two consecutive POS tags
	for (j = -2; j <= 1; j++) {
	    if (i + j >= 0 && i + j + 1 < seqLen) {
		// 4 = pp:
		String cp = "4:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + ":" +
			    tokens[i + j][1] + ":" + tokens[i + j + 1][1];
		tempCps.add(cp);
	    }
	}
	
	// three consecutive POS tags
	for (j = -2; j <= 0; j++) {
	    if (i + j >= 0 && i + j + 2 < seqLen) {
		// 5 = ppp:
		String cp = "5:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + Integer.toString(j + 2) + ":" +
			    tokens[i + j][1] + ":" + tokens[i + j + 1][1] + ":" + tokens[i + j + 2][1];
		tempCps.add(cp);
		
		/*
		if (j == -1) {
		    // 6 = pppw:
		    cp = "6:";
		    cp += Integer.toString(j) + Integer.toString(j + 1) +  
				Integer.toString(j + 2) + Integer.toString(j + 1) + ":" +
				tokens[i + j][1] + ":" + tokens[i + j + 1][1] + ":" + 
				tokens[i + j + 2][1] + ":" + tokens[i + j + 1][0];
		    tempCps.add(cp);
		}
		*/
	    }		
	}
	
	/*
	// single POS tag and single word
	for (j = -1; j <= 0; j++) {
	    if (i + j >= 0 && i + j < seqLen) {
		// 7 = pw:
		String cp = "7:";
		cp += Integer.toString(j) + Integer.toString(j) + ":" +
			    tokens[i + j][1] + ":" + tokens[i + j][0];
		tempCps.add(cp);
	    }
	}
	
	// two consecutive POS tags and single word
	for (j = -1; j < 0; j++) {
	    if (i + j >= 0 && i + j + 1 < seqLen) {
		// 8 = ppw:
		String cp = "8:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + Integer.toString(j) + ":" +
			    tokens[i + j][1] + ":" + tokens[i + j + 1][1] + ":" + tokens[i + j][0];
		tempCps.add(cp);
		
		// 9 = ppw:
		cp = "9:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + Integer.toString(j + 1) + ":" +
			    tokens[i + j][1] + ":" + tokens[i + j + 1][1] + ":" + tokens[i + j + 1][0];
		tempCps.add(cp);
	    }
	}
	
	// two consecutive words and single POS tag
	for (j = -1; j < 0; j++) {
	    if (i + j >= 0 && i + j + 1 < seqLen) {
		// 10 = pww:
		String cp = "10:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + Integer.toString(j) + ":" +
			    tokens[i + j][0] + ":" + tokens[i + j + 1][0] + ":" + tokens[i + j][1];
		tempCps.add(cp);
		
		// 11 = pww:
		cp = "11:";
		cp += Integer.toString(j) + Integer.toString(j + 1) + Integer.toString(j + 1) + ":" +
			    tokens[i + j][0] + ":" + tokens[i + j + 1][0] + ":" + tokens[i + j + 1][1];
		tempCps.add(cp);
	    }
	}
	*/
	
	List tempCpsInt = new ArrayList();
	
	for (int k = 0; k < tempCps.size(); k++) {
	    Integer cpInt = (Integer)cpStr2Int.get((String)tempCps.get(k));
	    if (cpInt == null) {
		continue;
	    }
	    tempCpsInt.add(cpInt);
	}
	
	Observation obsr = (Observation)seq.get(i);
	obsr.cps = new int[tempCpsInt.size()];
	
	for (int k = 0; k < tempCpsInt.size(); k++) {
	    obsr.cps[k] = ((Integer)tempCpsInt.get(k)).intValue();
	}
    }
    
    // context predicate generation for each sequence
    public void cpGen(Map cpStr2Int, List seq) {
	for (int i = 0; i < seq.size(); i++) {
	    cpGen(cpStr2Int, seq, i);	    
	}
    }    
    
    // context predicate generation
    public void cpGen(Map cpStr2Int) {
	System.out.println("Generating context predicates for input data ...");
	for (int i = 0; i < data.size(); i++) {
	    cpGen(cpStr2Int, (List)data.get(i));
	}
	System.out.println("Generating context predicates for input data completed!");
    }
    
} // end of class ChunkingData

