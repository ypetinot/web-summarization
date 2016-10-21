THRIFT_URL=http://mirror.cc.columbia.edu/pub/software/apache/thrift/0.9.3/thrift-0.9.3.tar.gz
THRIFT_ARCHIVE=$(notdir $(THRIFT_URL))
THRIFT_DIRECTORY=$(patsubst %.tar.gz,%,$(THRIFT_ARCHIVE))
THRIFT_DEBIAN_PACKAGE=libthrift-dev.deb

INSTALL_PREFIX=${ROOTDIR_THIRD_PARTY_DIST}

# CURRENT : still not able to install thrift libs in standard location. Currently have stanford-thrift use build location.

# TODO : how to get configure to enable the building/installation of Perl libraries ?
#        INSTALLDIRS=perl PERL_PREFIX=$(INSTALL_PREFIX)/lib
# TODO : as it is I also need to add a statement to specifically build the c++ libs ... => how can I correct this ?
# TOD/Note : java libraries are to be acquired via mvn dependency => for now I'm using an external repository (not perfect since disconnected from this installation), but ultimately I could push the java libraries to a local directory
default: $(INSTALL_PREFIX)/lib/Thrift


$(INSTALL_PREFIX)/lib/Thrift: $(THRIFT_DIRECTORY)/Makefile
	make && make install
	cp -rf $(THRIFT_DIRECTORY)/lib/perl/lib/* $(INSTALL_PREFIX)/lib/

$(THRIFT_DIRECTORY)/Makefile: $(THRIFT_DIRECTORY)
	# TODO : is there a way to disable all language libraries and to then only activate the ones I care about ?
	cd $< && ./configure --dataroot=$(CURDIR)/data/ --with-boost=$(INSTALL_PREFIX)/ --enable-tutorial=no --enable-tests=no --with-erlang=no --with-java=yes --with-php=no --with-python=no --with-cpp=yes --with-perl=yes --enable-tests=no

$(THRIFT_DIRECTORY): $(THRIFT_ARCHIVE)
	tar xzf $<

$(THRIFT_ARCHIVE):
	wget -O $@ $(THRIFT_URL)

$(THRIFT_DEBIAN_PACKAGE): $(THRIFT_DIRECTORY)
	cd $< && dpkg-buildpackage -d -td
	ln -s $</$(TRHIFT_DEBIAN-PACKAGE)

clean:
	rm -rf *~
	rm -rf $(THRIFT_ARCHIVE)
	rm -rf $(THRIFT_DIRECTORY)
