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

public class CRFChunker {
    public static void main(String[] args) {
	displayCopyright();
	
	if (!checkArgs(args)) {
	    displayHelp();
	    return;
	}
	
	String modelDir = args[1];
	boolean isInputFile = true;
	if (args[2].compareToIgnoreCase("-inputfile") != 0) {
	    isInputFile = false;
	}
	String inputFile = "";
	String inputDir = "";
	if (isInputFile) {
	    inputFile = args[3];
	} else {
	    inputDir = args[3];
	}
	
	Option chunkerOpt = new Option(modelDir);
	if (!chunkerOpt.readOptions()) {
	    return;
	}
	
	Maps chunkerMaps = new Maps();
	Dictionary chunkerDict = new Dictionary();
	FeatureGen chunkerFGen = new FeatureGen(chunkerMaps, chunkerDict);
	Viterbi chunkerVtb = new Viterbi();
	
	Model chunkerModel = new Model(chunkerOpt, chunkerMaps, chunkerDict, chunkerFGen, chunkerVtb);
	if (!chunkerModel.init()) {
	    System.out.println("Couldn't load the model");
	    System.out.println("Check the <model directory> and the <model file> again");
	    return;
	}
	
	ChunkingData chunkerData = new ChunkingData();
	
	if (isInputFile) {
	    chunkerData.readData(inputFile);
	    chunkerData.cpGen(chunkerMaps.cpStr2Int);

	    // inference
	    chunkerModel.inferenceAll(chunkerData.data);
	    
	    chunkerData.writeData(chunkerMaps.lbInt2Str, inputFile + ".chk");
	}
	
	if (!isInputFile) {
	    if (inputDir.endsWith(File.separator)) {
		inputDir = inputDir.substring(0, inputDir.length() - 1);
	    }
	    
	    File dir = new File(inputDir);
	    String[] children = dir.list();
	    
	    for (int i = 0; i < children.length; i++) {
		String filename = inputDir + File.separator + children[i];
		if ((new File(filename)).isDirectory()) {
		    continue;
		}
		
		chunkerData.readData(filename);
		chunkerData.cpGen(chunkerMaps.cpStr2Int);
		
		// inference
		chunkerModel.inferenceAll(chunkerData.data);
		
		chunkerData.writeData(chunkerMaps.lbInt2Str, filename + ".chk");
	    }
	}
	
    } // end of the main method
    
    public static boolean checkArgs(String[] args) {
	// case 1: CRFChunker -modeldir <model directory> -inputfile <input data file>
	// case 2: CRFChunker -modeldir <model directory> -inputdir <input data directory>
	
	if (args.length < 4) {	    
	    return false;
	}
	
	if (args[0].compareToIgnoreCase("-modeldir") != 0) {
	    return false;
	}
	
	if (!(args[2].compareToIgnoreCase("-inputfile") == 0 ||
		    args[2].compareToIgnoreCase("-inputdir") == 0)) {
	    return false;
	}
	
	return true;
    }   
    
    public static void displayCopyright() {
	System.out.println("English CRFChunker:");
	System.out.println("\tTrain on sections 01-24 of Wall Street Journal corpus");
	System.out.println("\tusing first-order Markov Conditional Random Fields");
	System.out.println("\ttesting on section 00 with the highest F1-measure of 95.77%");
	System.out.println("Copyright (C) by Xuan-Hieu Phan");
	System.out.println("Graduate School of Information Sciences, Tohoku University");
	System.out.println("Email: hieuxuan@ecei.tohoku.ac.jp");
	System.out.println();
    }
    
    public static void displayHelp() {
	System.out.println("Usage:");
	System.out.println("\tCase 1: CRFChunker -modeldir <model directory> -inputfile <input data file>");
	System.out.println("\tCase 2: CRFChunker -modeldir <model directory> -inputdir <input data directory>");
	System.out.println("Where:");
	System.out.println("\t<model directory> is the directory contain the model and option files");
	System.out.println("\t<input data file> is the file containing input sentences that need to");
	System.out.println("\tbe tagged (each sentence on a line)");
	System.out.println("\t<input data directory> is the directory containing multiple input data files");
	System.out.println();
    }
     
} // end of class CRFChunker

