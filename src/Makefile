SUBDIRS=java perl
SUBDIRS_CLEAN=$(addsuffix _clean, ${SUBDIRS})

.PHONY: default clean $(SUBDIRS) $(SUBDIRS_CLEAN)

default: $(SUBDIRS)

$(SUBDIRS):
	${MAKE} -C $@

clean: ${SUBDIRS_CLEAN}
	@rm -f *~

%_clean:
	${MAKE} -C $* clean
