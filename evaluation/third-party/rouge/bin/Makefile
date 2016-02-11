#include ../../../../build.mk

ROUGE_ROOT=${CURDIR}/../RELEASE-1.5.5/
RUN_ROUGE=run-rouge

.PHONY: clean

default: ${RUN_ROUGE} ${SETENV}

${RUN_ROUGE}:
	echo "${ROUGE_ROOT}/ROUGE-1.5.5.pl -e ${ROUGE_ROOT}/data -n 4 -z SPL \$$1" > ${RUN_ROUGE}
	chmod +x ${RUN_ROUGE}

clean:
	rm -f ${RUN_ROUGE}
	rm -f ${SETENV}
	rm -f *~

${SETENV}:
	echo "export PATH=${CURDIR}:\$$PATH" > ${SETENV}
