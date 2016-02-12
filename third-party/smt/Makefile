# requires libtool
# requires autoconf

#MOSES=moses-2010-04-26
#MOSES_ARCHIVE=${MOSES}.tgz
#MOSES_DIR=trunk

GIZA_PP_ARCHIVE=giza-pp-v1.0.3.tar.gz
GIZA_PP_DIR=giza-pp

M_GIZA_PP_ARCHIVE=mgizapp-0.6.3.tar.gz
M_GIZA_PP_DIR=mgizapp

# http://code.google.com/p/giza-pp/issues/detail?id=11
# http://code.google.com/p/giza-pp/issues/detail?id=3
GIZA_PP_PATCH=giza.ocelot.patch

LOCAL_ROOT=${CURDIR}/../local/
SRILM_ROOT=${CURDIR}/../local/

default: ${GIZA_PP_DIR}

${MOSES_DIR}:
	tar xzf ${MOSES_ARCHIVE}
	echo ${SRILM_ROOT}
	cd ${MOSES_DIR} && ./regenerate-makefiles.sh
	cd ${MOSES_DIR} && ./configure --prefix=${LOCAL_ROOT} --with-srilm=${SRILM_ROOT}/
	cd ${MOSES_DIR} && make install
	cd ${MOSES_DIR}/scripts && make TARGETDIR=${LOCAL_ROOT}/bin/

${GIZA_PP_DIR}:
	tar xzf ${GIZA_PP_ARCHIVE}
	cd ${GIZA_PP_DIR} && patch -p1 < ${CURDIR}/${GIZA_PP_PATCH} && make && cd GIZA++-v2/ && make INSTALLDIR=${LOCAL_ROOT}/bin install
	mkdir -p ${LOCAL_ROOT}/include/giza-pp/
	install -t ${LOCAL_ROOT}/include/giza-pp/ ${GIZA_PP_DIR}/GIZA++-v2/*.h

$(M_GIZA_PP_DIR):
	tar xzf $(M_GIZA_PP_ARCHIVE)
	cd $(M_GIZA_PP_DIR) && ./configure --prefix=$(LOCAL_ROOT) && make && make install

clean:
	rm -rf ${GIZA_PP_DIR}
	rm -rf ${MOSES_DIR}
	rm -rf $(M_GIZA_PP_DIR)
	rm -rf *~
