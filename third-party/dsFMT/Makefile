DSFMT_FILE=dSFMT-src-2.2.1.tar.gz
DSFMT_URL=http://www.math.sci.hiroshima-u.ac.jp/~m-mat/bin/dl/dl.cgi?SFMT:dSFMT-src-2.2.1.tar.gz
DSFMT_DIR=$(patsubst %.tar.gz,%,$(DSFMT_FILE))
DSFMT_TARGET=dsFMT

$(DSFMT_TARGET): $(DSFMT_FILE)
	tar xzf $(DSFMT_FILE)
	make -C $(DSFMT_DIR)
	ln -s $(DSFMT_DIR) $(DSFMT_TARGET)

$(DSFMT_FILE):
	wget -O $(DSFMT_FILE) $(DSFMT_URL)

clean:
	rm -rf *~
	rm -rf $(DSFMT_FILE)
	rm -rf $(DSFMT_DIR)
	rm -rf $(DSFMT_TARGET)
