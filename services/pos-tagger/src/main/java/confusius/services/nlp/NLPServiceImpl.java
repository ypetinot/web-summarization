package confusius.services.nlp;

import org.osoa.sca.annotations.Reference;

/**
 * An implementation of the NLP service.
 */
public class NLPServiceImpl implements NLPService {

    private PartOfSpeechTagger posService;

    @Reference
	public void setPosTaggerService(PartOfSpeechTagger posService) {
        this.posService = posService;
    }


}
