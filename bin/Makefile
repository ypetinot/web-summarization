include ../build.mk

SETENV=setenv

RUN_SUMMARIZER=run-summarizer
RUN_SUMMARIZER_TEMPLATE:=${RUN_SUMMARIZER}.tpl

.PHONY: clean

default: ${RUN_SUMMARIZER} ${SETENV}

${RUN_SUMMARIZER}:
	# TODO: not quite what I wanted but can be easily improved in the future
	echo "export CONTEXT_SUMMARIZATION_ROOT=${CONTEXT_SUMMARIZATION_ROOT}" > ${RUN_SUMMARIZER}
	echo "export CONTEXT_SUMMARIZATION_COMMON_ROOT=${CONTEXT_SUMMARIZATION_COMMON_ROOT}" >> ${RUN_SUMMARIZER}
	echo >> ${RUN_SUMMARIZER}
	cat ${RUN_SUMMARIZER_TEMPLATE} >> ${RUN_SUMMARIZER}
	chmod +x ${RUN_SUMMARIZER}

clean:
	rm -f ${RUN_SUMMARIZER}
	rm -f ${SETENV}
	rm -f *~

${SETENV}:
	echo "export PATH=${CURDIR}/bin:\$$PATH" > ${SETENV}
