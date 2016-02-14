// tells Scala where to find the TMT classes
import scalanlp.io._;
import scalanlp.stage._;
import scalanlp.stage.text._;
import scalanlp.text.tokenize._;
import scalanlp.pipes.Pipes.global._;

import edu.stanford.nlp.tmt.stage._;
import edu.stanford.nlp.tmt.model.lda._;
import edu.stanford.nlp.tmt.model.llda._;

val input_path = System.getenv("INPUT_HLLDA");
val model_path = System.getenv("MODEL_HLLDA");
//val n_iterations = Integer.parseInt(System.getenv("NUMBER_OF_ITERATIONS"));

println("[HLLDA] Input Path: " + input_path);
println("[HLLDA] Model Path: " + model_path);
//println("[HLLDA] Number of Iterations: " + n_iterations);

// the path of the model to load
val modelPath = file(model_path);

/* load the trained model */
println("Loading " + modelPath);
val model = LoadCVB0LabeledLDA(modelPath);
// Or, for a Gibbs model, use:
//val model = LoadGibbsLabeledLDA(modelPath);

// A new dataset for inference.  (Here we use the same dataset
// that we trained against, but this file could be something new.)
val source = CSVFile(input_path) ~> IDColumn(1);

val text = {
  source ~>                              // read from the source file
  Column(2) ~>                           // select column containing text
  TokenizeWith(model.tokenizer.get)      // tokenize with existing model's tokenizer
}

/* should be same way of constructing labels as for the training set */
/* is there a better way of doing this ? */
val labels = {
  source ~>                              // read from the source file
  Column(3) ~>                           // take column two, the year
  TokenizeWith(model.tokenizer.get) ~> // turns label field into an array
  TermCounter() ~>                       // collect label counts
  TermMinimumDocumentCountFilter(0)      // filter labels in < 10 docs
}

/* load testing dataset */
// turn the text into a dataset ready to be used with HLLDA
val testing_dataset = LabeledLDADataset(text, labels, termIndex = model.termIndex, labelIndex = model.params.labelIndex);

/* we use TMT's ability to compute the perplexity over held-out data */
//val perplexity = model.computePerplexity(testing_dataset);
//println(perplexity);
val output="yves.test";
println("Writing document distributions to "+output+"-document-topic-distributions.csv");
val perDocTopicDistributions = InferDocumentTopicDistributions(model, testing_dataset);
CSVFile(output+"-document-topic-distributuions.csv").write(perDocTopicDistributions);

println("Writing topic usage to "+output+"-usage.csv");
val usage = QueryTopicUsage(model, testing_dataset, perDocTopicDistributions);
CSVFile(output+"-usage.csv").write(usage);
