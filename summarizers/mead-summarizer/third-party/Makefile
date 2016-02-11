MEAD=mead
PERL5LIB=""

default: mead setenv

${MEAD}:
	tar xzf *.gz
# will not work with perl 5.10
#	for file in `grep -lr '/usr/bin/perl' ${MEAD}/*`; do sed -i 's/\/usr\/bin\/perl\( -w\)\?/\/usr\/bin\/env perl/' $$file; done;
	cd ${MEAD} && perl Install.PL
	@chmod -R +r,+x ${MEAD}/*

setenv:
	@echo "export PATH=\$$PATH:${CURDIR}/${MEAD}/bin/" >> ${CURDIR}/../setenv

clean:
	@rm -rf *~ $(MEAD)
