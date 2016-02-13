OPENNLP_URL=http://mirror.reverse.net/pub/apache//opennlp/opennlp-1.5.3/apache-opennlp-1.5.3-bin.tar.gz
OPENNLP_ARCHIVE=$(notdir $(OPENNLP_URL))
OPENNLP_DIRECTORY=$(patsubst %-bin.tar.gz,%,$(OPENNLP_ARCHIVE))
OPENNLP_BIN=$(CURDIR)/bin
OPENNLP_MODELS=$(CURDIR)/models
OPENNLP_MODELS_LIST=$(OPENNLP_MODELS).list

default: $(OPENNLP_BIN) $(OPENNLP_MODELS)

$(OPENNLP_BIN): $(OPENNLP_DIRECTORY)
	ln -s $(OPENNLP_DIRECTORY)/bin

$(OPENNLP_ARCHIVE):
	wget -O $(OPENNLP_ARCHIVE) $(OPENNLP_URL)

$(OPENNLP_DIRECTORY): $(OPENNLP_ARCHIVE)
	tar xzf $<

$(OPENNLP_MODELS): $(OPENNLP_MODELS_LIST)
	mkdir -p $@
	cd $@ && wget -i $<

clean:
	rm -rf *~
	rm -rf $(OPENNLP_ARCHIVE)
	rm -rf $(OPENNLP_DIRECTORY)
	rm -rf $(OPENNLP_BIN)
	rm -rf $(OPENNLP_MODELS)
