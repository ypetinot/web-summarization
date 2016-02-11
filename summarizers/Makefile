SUBDIRS=$(shell find -mindepth 1 -maxdepth 1 -type d -not -name '\.*')
SUBDIRS_CLEAN=$(addsuffix _clean, $(SUBDIRS))

.PHONY: default clean $(SUBDIRS)

default: $(SUBDIRS)

$(SUBDIRS):
	${MAKE} -C $@

clean: ${SUBDIRS_CLEAN}
	@rm -f *~

%_clean:
	${MAKE} -C $* clean
