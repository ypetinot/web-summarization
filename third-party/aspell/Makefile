ASPELL_ARCHIVE=ftp://alpha.gnu.org/gnu/aspell/aspell-0.60.7-20110707.tar.gz

default: aspell

aspell-archive:
	wget $(ASPELL_ARCHIVE)

aspell: aspell-archive
	tar xzf *.tar.gz
	cd aspell* && ./configure --prefix=${CURDIR}/../local/ && make && make install && cd ..

clean:
	rm -rf *~
	rm -rf aspell*