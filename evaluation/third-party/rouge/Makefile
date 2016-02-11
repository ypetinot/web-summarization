ROUGE=RELEASE-1.5.5
#SETENV=setenv

SUBDIRS=bin

.PHONY: clean ${SUBDIRS}

default: ${ROUGE} ${SUBDIRS}

${ROUGE}:
	tar xzf *.tgz

${SUBDIRS}:
	make -C $@

clean:
	$(foreach subdir, ${SUBDIRS}, make -C ${subdir} clean)
	@rm -rf *~ ${ROUGE}

