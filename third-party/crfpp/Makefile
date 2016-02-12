CRFPP_ARCHIVE=CRF++-0.58.tar.gz
CRFPP_DIRECTORY=$(patsubst %.tar.gz,%,$(CRFPP_ARCHIVE))
BUILD_DIRECTORY=$(CURDIR)/build/

default: $(CRFPP_DIRECTORY)

$(CRFPP_DIRECTORY): $(CRFPP_ARCHIVE)
	tar xzf $<
	cd $@ && ./configure --prefix=$(BUILD_DIRECTORY) && make && make install

clean:
	rm -rf *~
	rm -rf $(CRFPP_DIRECTORY) $(BUILD_DIRECTORY)
