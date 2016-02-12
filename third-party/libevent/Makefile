#LIBEVENT_URL=http://downloads.sourceforge.net/project/levent/libevent/libevent-2.0/libevent-2.0.22-stable.tar.gz?r=http%3A%2F%2Flibevent.org%2F&ts=1438382402&use_mirror=iweb
LIBEVENT_URL=http://downloads.sourceforge.net/project/levent/libevent/libevent-2.0/libevent-2.0.22-stable.tar.gz
LIBEVENT_ARCHIVE=$(notdir $(LIBEVENT_URL))
LIBEVENT_DIRECTORY=$(patsubst %.tar.gz,%,$(LIBEVENT_ARCHIVE))

# TODO : get from dist.rc ?
INSTALL_PREFIX=$(CURDIR)/../local/

default: $(LIBEVENT_DIRECTORY)
	cd $< && ./configure --prefix=$(INSTALL_PREFIX) && make && make install
#	cp -rf $(THRIFT_DIRECTORY)/lib/perl/lib/* $(INSTALL_PREFIX)/lib/

$(LIBEVENT_DIRECTORY): $(LIBEVENT_ARCHIVE)
	tar xzf $<

$(LIBEVENT_ARCHIVE):
	wget -O $@ '$(LIBEVENT_URL)'

clean:
	rm -rf *~
	rm -rf $(LIBEVENT_ARCHIVE)
	rm -rf $(LIBEVENT_DIRECTORY)
