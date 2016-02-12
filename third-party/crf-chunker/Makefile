CRF_TAGGER_URL=http://downloads.sourceforge.net/project/crftagger/crftagger/1.0/CRFTagger-1.0.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fcrftagger%2F&ts=1369702115&use_mirror=iweb
CRF_CHUNKER_URL=http://downloads.sourceforge.net/project/crfchunker/crfchunker/1.0/CRFChunker-1.0.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fcrfchunker%2F&ts=1369713007&use_mirror=iweb

CRF_TAGGER_TARGET=CRFTagger
CRF_CHUNKER_TARGET=CRFChunker

default: ${CRF_TAGGER_TARGET} ${CRF_CHUNKER_TARGET}

${CRF_TAGGER_TARGET}: ${CRF_TAGGER_TARGET}.tar.gz
	tar xzf $@.tar.gz
	make -C $@

${CRF_TAGGER_TARGET}.tar.gz:
	wget -O $@ "${CRF_TAGGER_URL}"

${CRF_CHUNKER_TARGET}: ${CRF_CHUNKER_TARGET}.tar.gz
	tar xzf $@.tar.gz
	make -C $@

${CRF_CHUNKER_TARGET}.tar.gz:
	wget -O $@ "${CRF_CHUNKER_URL}"

clean:
	@rm -rf ${CRF_CHUNKER_TARGET} ${CRF_TAGGER_TARGET}
	@rm -rf *.tar.gz
	@rm -rf *~
