PROTOBUF=protobuf-2.3.0
PROTOBUF_ARCHIVE=$(PROTOBUF).tar.gz

SPARSEHASH=sparsehash-1.10
SPARSEHASH_ARCHIVE=$(SPARSEHASH).tar.gz

GLOG=glog-0.3.1
GLOG_ARCHIVE=${GLOG}-1.tar.gz

GFLAGS=gflags-1.5
GFLAGS_ARCHIVE=${GFLAGS}.tar.gz

INSTALL_HOME=$(CURDIR)/../local/

default: $(PROTOBUF) $(SPARSEHASH) $(GLOG) $(GFLAGS)

.PHONY= clean

$(PROTOBUF): $(PROTOBUF_ARCHIVE)
	tar xzf $(PROTOBUF_ARCHIVE)
	cd $(PROTOBUF) && ./configure --prefix=$(INSTALL_HOME) && make && make install

$(SPARSEHASH): $(SPARSEHASH_ARCHIVE)
	tar xzf $<
	cd $@ && ./configure --prefix=$(INSTALL_HOME) && make && make install

$(GLOG): $(GLOG_ARCHIVE)
	tar xzf $<
	cd $@ && ./configure --prefix=$(INSTALL_HOME) && make && make install

$(GFLAGS): $(GFLAGS_ARCHIVE)
	tar xzf $<
	cd $@ && ./configure --prefix=$(INSTALL_HOME) && make && make install	

clean:
	rm -rf $(PROTOBUF) $(SPARSEHASH) $(GLOG) $(GFLAGS) *~

