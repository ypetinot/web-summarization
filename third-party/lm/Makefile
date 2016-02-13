CMU_CAM_TOOLKIT=CMU-Cam_Toolkit_v2
CMU_CAM_TOOLKIT_ARCHIVE=${CMU_CAM_TOOLKIT}.tar.gz

SRILM_TOOLKIT=srilm
SRILM_TOOLKIT_ARCHIVE=${SRILM_TOOLKIT}.tgz

default: ${CMU_CAM_TOOLKIT} ${SRILM_TOOLKIT}

.PHONY:

deploy_dirs:
	mkdir -p ${CURDIR}/../local/bin
	mkdir -p ${CURDIR}/../local/lib/i686/
	mkdir -p ${CURDIR}/../local/include
	mkdir -p ${CURDIR}/../local/sbin

${CMU_CAM_TOOLKIT}: deploy_dirs
	tar xzf ${CMU_CAM_TOOLKIT_ARCHIVE}
	cd ${CMU_CAM_TOOLKIT}/src/ && make install && cp ../bin/* ${CURDIR}/../local/bin/

##${SRILM_TOOLKIT}: deploy_dirs
##	mkdir -p ${SRILM_TOOLKIT}
##	cd ${SRILM_TOOLKIT} && tar xzf ../${SRILM_TOOLKIT_ARCHIVE} && cp -f ../Makefile.machine.i686-gcc4 ./common/ && sed -i 's/^\# SRILM = .*$$/SRILM = $${CURDIR}/' Makefile && make MACHINE_TYPE=i686-gcc4 && cd ../
##	find ${SRILM_TOOLKIT}/bin/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/bin/
##	find ${SRILM_TOOLKIT}/lib/i686-gcc4/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/lib/i686
##	find ${SRILM_TOOLKIT}/include/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/include/
##	find ${SRILM_TOOLKIT}/sbin/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/sbin/

${SRILM_TOOLKIT}: deploy_dirs
	mkdir -p ${SRILM_TOOLKIT}
	cd ${SRILM_TOOLKIT} && tar xzf ../${SRILM_TOOLKIT_ARCHIVE} && make SRILM=$(CURDIR)/$(SRILM_TOOLKIT) && cd ../
	find ${SRILM_TOOLKIT}/bin/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/bin/
	find ${SRILM_TOOLKIT}/lib/i686-gcc4/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/lib/i686
	find ${SRILM_TOOLKIT}/include/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/include/
	find ${SRILM_TOOLKIT}/sbin/ -type f | xargs -i{} cp -f {} ${CURDIR}/../local/sbin/

clean:
	rm -rf *~
	rm -rf ${CMU_CAM_TOOLKIT}
	rm -rf ${SRILM_TOOLKIT}
