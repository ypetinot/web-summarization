#include ../build.mk

#TODO: move URLs to build.properties file

ANT_URL=http://www.apache.org/dist/ant/binaries/apache-ant-1.7.1-bin.tar.gz
ANT=ant
ANT_DIR=apache-ant-*

EXPAT=expat-2.0.1

#JDK=jdk-6u5-linux-i586
#JDK_DIR=jdk1.6.0_05

TOMCAT_URL=http://apache.cs.utah.edu/tomcat/tomcat-6/v6.0.18/bin/apache-tomcat-6.0.18.tar.gz
TOMCAT=tomcat
TOMCAT_DIR=apache-tomcat-*

#STANFORD=stanford-parser-2008-10-26

SQLITE_URL=http://www.sqlite.org/sqlite-amalgamation-3.6.17.tar.gz
SQLITE=sqlite
SQLITE_DIR=sqlite-3.6.17

BUILD_ROOT=${CURDIR}/build
LOCAL_ROOT=${CURDIR}/local
BUILD_MK=build.mk

LM=lm
PERL=perl
TOKYOCABINET=tokyocabinet

.PHONY: $(PERL)
default: $(PERL) ${TOKYOCABINET} ${EXPAT} ${JDK} ${BUILD_MK}

${BUILD_ROOT}:
	mkdir -p ${BUILD_ROOT}

${LOCAL_ROOT}: ${BUILD_ROOT}
	mkdir -p ${LOCAL_ROOT}

${EXPAT}: ${LOCAL_ROOT}
	tar -C ${BUILD_ROOT} -xzf ${EXPAT}.tar.gz
	cd ${BUILD_ROOT}/${EXPAT} && ./configure --prefix=${LOCAL_ROOT} && make && make install

#${JDK}: ${LOCAL_ROOT}
#	tar -C ${BUILD_ROOT} -xzf ${JDK}.tgz
#	cp -rf ${BUILD_ROOT}/${JDK_DIR}/bin ${LOCAL_ROOT}/
#	cp -rf ${BUILD_ROOT}/${JDK_DIR}/lib ${LOCAL_ROOT}/
#	cp -rf ${BUILD_ROOT}/${JDK_DIR}/jre ${LOCAL_ROOT}/

${TOMCAT}: ${BUILD_ROOT} ${LOCAL_ROOT}
	wget ${TOMCAT_URL} -O ${BUILD_ROOT}/${TOMCAT}
	tar -C ${BUILD_ROOT} -xzf ${BUILD_ROOT}/${TOMCAT}
	find ${BUILD_ROOT}/${TOMCAT_DIR}/ -mindepth 1 -maxdepth 1 -type d | xargs -i{} cp -rf {} ${LOCAL_ROOT}/

${ANT}: ${BUILD_ROOT} ${LOCAL_ROOT}
	wget ${ANT_URL} -O ${BUILD_ROOT}/${ANT}
	tar -C ${BUILD_ROOT} -xzf ${BUILD_ROOT}/${ANT}
	find ${BUILD_ROOT}/${ANT_DIR}/ -mindepth 1 -maxdepth 1 -type d | xargs -i{} cp -rf {} ${LOCAL_ROOT}/

#${STANFORD}:
#	tar -C ${BUILD_ROOT} -xzf ${STANFORD}.tgz
#	find ${BUILD_ROOT}/${STANFORD}/ -name '*.jar' | xargs -i{} cp {} ${LOCAL_ROOT}/jre/lib/ext/

${SQLITE}: ${BUILD_ROOT} ${LOCAL_ROOT}
	wget ${SQLITE_URL} -O ${BUILD_ROOT}/${SQLITE}
	tar -C ${BUILD_ROOT} -xzf ${BUILD_ROOT}/${SQLITE}
	cd ${BUILD_ROOT}/${SQLITE_DIR} && ./configure --prefix=${LOCAL_ROOT} && make && make install

${BUILD_MK}:
	echo "export C_INCLUDE_PATH=${LOCAL_ROOT}/include/" > ${BUILD_MK}
	echo "export CPLUS_INCLUDE_PATH=${LOCAL_ROOT}/include/" >> ${BUILD_MK}
	echo "export LIBRARY_PATH=${LOCAL_ROOT}/lib/" >> ${BUILD_MK}

$(PERL): ${BUILD_ROOT} ${LOCAL_ROOT}
	$(MAKE) -C ${PERL}

$(LM): $(BUILD_ROOT) $(LOCAL_ROOT)
	$(MAKE) -C $(LM) 

${TOKYOCABINET}: ${BUILD_ROOT} ${LOCAL_ROOT}
	$(MAKE) -C ${TOKYOCABINET}

clean:
	$(MAKE) -C $(LM) clean
	$(MAKE) -C ${PERL} clean
	$(MAKE) -C ${TOKYOCABINET} clean
	rm -rf ${BUILD_MK}
	rm -rf ${BUILD_ROOT}
	rm -rf ${LOCAL_ROOT}
	rm -rf *~
