#include ../../build.mk

TOKYOCABINET_LIB=tokyocabinet-1.4.43
TOKYOCABINET_LIB_ARCHIVE=${TOKYOCABINET_LIB}.tar.gz

TOKYOCABINET_PERL=tokyocabinet-perl-1.34
TOKYOCABINET_PERL_ARCHIVE=${TOKYOCABINET_PERL}.tar.gz

default:
	tar xzf ${TOKYOCABINET_LIB_ARCHIVE}
	tar xzf ${TOKYOCABINET_PERL_ARCHIVE}
	cd ${TOKYOCABINET_LIB} && ./configure --prefix=${CURDIR}/../local/ --enable-off64 && make && make install
	cd ${TOKYOCABINET_PERL} && export PERL5LIB=${CURDIR}/../local/lib/ && export C_INCLUDE_PATH=${CURDIR}/../local/include/ && perl Makefile.PL PREFIX=${CURDIR}/../local/ LIB=${CURDIR}/../local/lib/ LIBS="-L${CURDIR}/../local/lib/ -ltokyocabinet" && make && make test && make install

clean:
	rm -rf ${TOKYOCABINET_LIB}
	rm -rf ${TOKYOCABINET_PERL}
	rm -rf *~
