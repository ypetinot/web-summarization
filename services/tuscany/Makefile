include ../../build.mk

TUSCANY_URL=http://apache.mirror99.com/tuscany/java/sca/1.4/apache-tuscany-sca-1.4.tar.gz
TUSCANY=apache-tuscany-sca-1.4.tar.gz
TUSCANY_DIR=tuscany-sca-1.4

BUILD_ROOT=${CURDIR}/build

default: ${TUSCANY}

${BUILD_ROOT}:
	mkdir -p ${BUILD_ROOT}

${TUSCANY}: ${BUILD_ROOT}
	wget ${TUSCANY_URL} -O ${BUILD_ROOT}/${TUSCANY}
	tar -C ${BUILD_ROOT} -xzf ${BUILD_ROOT}/${TUSCANY}
	cp -rf ${BUILD_ROOT}/${TUSCANY_DIR}/lib .
	cp -rf ${BUILD_ROOT}/${TUSCANY_DIR}/modules .

clean:
	rm -rf ${BUILD_ROOT}
	rm -rf lib
	rm -rf modules
	rm -rf *~
