package confusius.services.nlp;

import org.osoa.sca.annotations.Remotable;

@Remotable
public interface SentenceChunker {

    public String chunk(String text);

}
