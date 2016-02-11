include ../build.mk

TUSCANY=tuscany
SERVICES=pos-tagger
SERVICES_CLEAN=$(TUSCANY)_clean $(patsubst %, %_clean, ${SERVICES})

.PHONY: ${TUSCANY} ${SERVICES} clean
default: ${SERVICES}

${SERVICES}: ${TUSCANY}
	make -C $@

${TUSCANY}:
	make -C $@

clean: $(SERVICES_CLEAN)
	rm -rf *~

%_clean:
	make -C $* clean
