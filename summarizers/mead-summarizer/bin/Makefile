SETENV=setenv

default:${SETENV}

${SETENV}:
	@echo "export PATH=${CURDIR}:${PATH}" > setenv;

clean:
	rm -f ${SETENV}
	rm -f *.lock
	rm -f *~
