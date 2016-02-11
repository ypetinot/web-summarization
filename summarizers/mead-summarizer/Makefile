SUBDIRS=third-party
SETENV=setenv

default: setenv
	@for dir in ${SUBDIRS}; do\
        	make -C $$dir; \
        done;

setenv:
	@echo "export PATH=${CURDIR}/bin/:\$$PATH" > ${SETENV}

clean:
	@for dir in ${SUBDIRS}; do\
                make -C $$dir clean; \
        done;
	rm -f ${SETENV}
	rm -f *~
