SUBDIRS=rouge
default:
	@for dir in ${SUBDIRS}; do\
		make -C $$dir; \
	done;

clean:
	@for dir in ${SUBDIRS}; do\
                make -C $$dir clean; \
        done;
	rm -f *~
