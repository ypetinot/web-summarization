// Hierarchical Labeled LDA

// tells Scala where to find the TMT classes
import scalanlp.io._;
import scalanlp.stage._;
import scalanlp.stage.text._;
import scalanlp.text.tokenize._;
import scalanlp.pipes.Pipes.global._;

import edu.stanford.nlp.tmt.stage._;
import edu.stanford.nlp.tmt.model.lda._;
import edu.stanford.nlp.tmt.model.llda._;
import edu.stanford.nlp.tmt.learn._;

val input_path = System.getenv("INPUT_HLLDA");
val model_path = System.getenv("OUTPUT_HLLDA");
val n_iterations = Integer.parseInt(System.getenv("NUMBER_OF_ITERATIONS"));

println("[HLLDA] Input Path: " + input_path);
println("[HLLDA] Model Path: " + model_path);
println("[HLLDA] Number of Iterations: " + n_iterations);

val source = CSVFile(input_path) ~> IDColumn(1);

val tokenizer = {
  SimpleEnglishTokenizer() ~>            // tokenize on space and punctuation
  MinimumLengthFilter(0)              // take terms with >=3 characters	
}

val text = {
  source ~>                              // read from the source file
  Column(2) ~>                           // select column containing text
  TokenizeWith(tokenizer) ~> 		 // tokenize with tokenizer above
  TermCounter() ~>                       // collect counts (needed below)
  DocumentMinimumLengthFilter(0)         // take only docs with >=5 terms
}

// display information about the loaded dataset
println("Description of the loaded text field:");
println(text.description);

println();
println("------------------------------------");
println();

// define fields from the dataset we are going to slice against
val labels = {
  source ~>                              // read from the source file
  Column(3) ~>                           // take column two, the year
  TokenizeWith(WhitespaceTokenizer()) ~> // turns label field into an array
  TermCounter() ~>                       // collect label counts
  TermMinimumDocumentCountFilter(0)      // filter labels in < 10 docs
}

println("Creating L-LDA dataset ..."); 
val dataset = LabeledLDADataset(text, labels);

// define the model parameters
println("Creating L-LDA parameters ...");
val modelParams = LabeledLDAModelParams(dataset);

// Name of the output model folder to generate
println("Creating model file ...");
val modelPath = file(model_path);

// Trains the model, writing to the given output path
println("Running model inference ...");
//TrainCVB0LabeledLDA(modelParams, dataset, output = modelPath, maxIterations = n_iterations);
val modeler = ThreadedModeler(CVB0LabeledLDA,20);
modeler.train(modelParams, dataset, modelPath, saveDataState = false, maxIterations = n_iterations);
val table : Iterable[(String,List[(Int,Double)])] = modeler.data.view.map(doc => (doc.id,doc.signature.activeIterator.toList));
CSVFile(modelPath, "document-topic-distributions.csv").write(table);
//return modeler.model.get;

//TrainCVB0LabeledLDA(modelParams, dataset, output = modelPath, maxIterations = 1000);
//TrainGibbsLabeledLDA(modelParams, dataset, output = modelPath, maxIterations = n_iterations);
