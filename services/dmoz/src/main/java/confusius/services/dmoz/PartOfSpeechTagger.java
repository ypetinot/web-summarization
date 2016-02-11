package confusius.services.nlp;

import org.osoa.sca.annotations.Remotable;

@Remotable
public interface PartOfSpeechTagger {
	
    String parse(String text);

}
