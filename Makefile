##BUILD_MK=build.mk
##BUILD_MK_TPL=${BUILD_MK}.tpl

#SUBDIRS=$(shell find -mindepth 1 -maxdepth 1 -type d -not -name '\.*')
SUBDIRS=third-party
SUBDIRS_CLEAN=$(addsuffix _clean, ${SUBDIRS})

DATA=data
FRAMEWORK=bin lib
SUMMARIZERS=summarizers

DIRECTORY_TARGETS=${SUPPORT} $(SUMMARIZERS)

.PHONY: bin clean common $(DIRECTORY_TARGETS)

default: ${DIRECTORY_TARGETS} bin

$(DIRECTORY_TARGETS): ${BUILD_MK}

${BUILD_MK}:
	echo "export CONTEXT_SUMMARIZATION_ROOT:=${CURDIR}" > ${BUILD_MK}
	echo >> ${BUILD_MK}
	cat ${BUILD_MK_TPL} >> ${BUILD_MK}

${SUMMARIZERS}:
	${MAKE} -C $@

common bin ${SUPPORT}:
	${MAKE} -C $@

distro: clean
	@tar czf distro.tgz *

clean: ${SUBDIRS_CLEAN}
	@rm -f ${RUN_SUMMARIZER}
	@rm -f ${BUILD_MK}
	@rm -f distro.tgz
	@rm -f *~

%_clean:
	${MAKE} -C $* clean
