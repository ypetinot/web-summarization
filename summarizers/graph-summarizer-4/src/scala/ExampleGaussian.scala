// CURRENT : variables => the filler of the slot instance => attached to unary factors
// CURRENT : binary factors => similarity constraints between variables
import scala.util.parsing.json._
//import scala.collection.mutable.Map
import scala.collection.mutable.HashMap

class SlotModel {

// TODO : reinstate ?
//extends App {

    import cc.factorie._    	                                // The base library
    import cc.factorie.la           // Linear algebra: tensors, dot-products, etc.
    import cc.factorie.optimize._   // Gradient-based optimization and training
    import cc.factorie.variable._						      
    import cc.factorie.model._
    import cc.factorie.infer._

    class SlotInstance(
    	  val id: String,
	  val features : Map[String,Any]
    )

val parameters = new HashMap[String,Int];

// <instance_id> \t <candidate_filler> \t <candidate_filler_features>
// CURRENT : separate file to provide interactions or these can be computed here ?
// TODO : how can we make variable definitions to be non-lazy ? (at least when executed as a script)
val instances = for ( ln <- io.Source.stdin.getLines ) yield {
    val fields = ln.split("\t");
    val instance_features = JSON.parseFull( fields( 2 ) ) match {
        case Some(mapField) => mapField.asInstanceOf[Map[String,Any]]
	case _ => new HashMap[String,Any] };
//    val instance_features = JSON.parseFull( fields( 2 ) );
    for ( instance_feature <- instance_features.keys ) {
    	parameters.put( instance_feature , 1 );
    };
    new SlotInstance( fields( 0 ) , instance_features.asInstanceOf[Map[String,Any]] );
}

// TODO : how can we avoid having to do this ?
while( instances.hasNext ) {
//       println( instances.next.features );
	 instances.next.features;
}

      val number_of_parameters = parameters.size;
      val model = new Model with Parameters {

      	// CURRENT : what kind of argument is factors being passed ?
      	// one factor per instance (ie. this is an unrolled model ?)
	def factors(slot_instances:Iterable[Var]) = slot_instances match {

	    case slot_instance:SlotInstance => {

		// A domain and variable type for storing slot fillers => instance specific
    	    	object SlotFillerDomain extends CategoricalDomain[String]
    	    	implicit class SlotFiller(slot_instance:SlotInstance) extends CategoricalVariable(slot_instance.id) {
    	      	  def domain = SlotFillerDomain
    	    	}

    	    	val observ = new DotFamilyWithStatistics1[SlotFiller] {
      	    	       val weights = Weights( new DenseTensor1( number_of_parameters ) )
    	        }

		//new observ.Factor( new SlotFiller( slot_instance ) );
		new observ.Factor( slot_instance );

	    } 

       }

    }

    // Learn parameters
    // CURRENT : type of model => unrolled models possible (i.e. no instances ?)
    val trainer = new BatchTrainer(model.parameters, new ConjugateGradient)
    trainer.trainFromExamples(labelSequences.map(labels => new LikelihoodExample(labels, model, InferByBPChain)))

/*							/
    // Inference on the same data.  We could let FACTORIE choose the inference method, 
    // but here instead we specify that is should use max-product belief propagation
    // specialized to a linear chain
    labelSequences.foreach(labels => BP.inferChainMax(labels, model))
*/

}

val slot_model = new SlotModel;
val slot_model_number_of_parameters = slot_model.number_of_parameters;
println( slot_model_number_of_parameters );
println( "Done !" )

/*
  // Print the learned parameters on the Markov factors.
  println(model.markov.weights)

  // Print the inferred tags
  labelSequences.foreach(_.foreach(l => println(s"Token: ${l.token.value} Label: ${l.value}")))
*/

/*

    	// Given some variables, return the collection of factors that neighbor them.
    	def factors(labels:Iterable[Var]) = labels match {
      	    case labels:LabelSeq => 
            labels.map(label => new observ.Factor(label, label.token))
            		     ++ labels.sliding(2).map(window => new markov.Factor(window.head, window.last))
    	    }

*/

/*
    // Generate 1000 new random variables from this Gaussian distribution
    //  "~" would mean just "Add to the model a new factor connecting the parents and the child"
    //  ":~" does this and also assigns a new value to the child by sampling from the factor
    val data = for (i <- 1 to 1000) yield new DoubleVariable :~ Gaussian(mean, variance) 

*/

/*
	/* the similarity constraints are not learned */
	// Two families of factors, where factor scores are dot-products of sufficient statistics and weights.
    	// (The weights will set in training below.)
    	val similarity_markov = new DotFamilyWithStatistics2[SlotFiller,SlotFiller] { 
      	    val weights = Weights(new la.DenseTensor2(LabelDomain.size, LabelDomain.size))
    	}

	new observ.Factor(label, label.token))
        ++ labels.sliding(2).map(window => new markov.Factor(window.head, window.last))

*/
