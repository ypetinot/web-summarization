WORDNET=WordNet-3.0
WORDNET_ARCHIVE=${WORDNET}.tar.gz

WORDNET_PERL_QUERY_DATA=WordNet-QueryData-1.49
WORDNET_PERL_SIMILARITY=WordNet-Similarity-2.05

WORDNET_PERL_MODULES:=$(WORDNET_PERL_QUERY_DATA) $(WORDNET_PERL_SIMILARITY)
$(warning $(WORDNET_PERL_MODULES))
default: wordnet-install $(WORDNET_PERL_MODULES)

$(WORDNET_PERL_SIMILARITY): $(WORDNET_PERL_QUERY_DATA)

define PERL_MODULE_MAKE_template
$(1): $(1).tar.gz
	tar xzf $$<
	export WNHOME=${CURDIR}/../local/ && export PERL5LIB=$(CURDIR)/../local/lib/ && cd $$@ && perl Makefile.PL PREFIX=${CURDIR}/../local/ LIB=${CURDIR}/../local/lib/ && make && make install
endef

$(foreach perl_module, $(WORDNET_PERL_MODULES), $(eval $(call PERL_MODULE_MAKE_template, $(perl_module))))

wordnet-install:
	tar xzf ${WORDNET_ARCHIVE}
	cd ${WORDNET} && ./configure --prefix=${CURDIR}/../local/ && make && make install

clean:
	rm -rf *~
	rm -rf ${WORDNET}
	rm -rf $(WORDNET_PERL_MODULES)
