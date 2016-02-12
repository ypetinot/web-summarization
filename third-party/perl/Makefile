default: cpan

# TODO : can we do better than redirecting STDOUT to /dev/null ?
bundle_install=$(shell export THIRD_PARTY_PERL_ROOT=$(CURDIR)/../local/ && export HOME=$(CURDIR) && export PERL5LIB="$(CURDIR)/.cpan/:$(CURDIR):$(CURDIR)/../local/lib/" && export CPAN_BUILD_ROOT=`mktemp -d` && perl -MCPAN -e "install $1" )

cpan: build_clean
#	$(call bundle_install,"Bundle::Environment" )
	make "install-Bundle::Environment"
#	$(call bundle_install,"Bundle::Common" )
	make "install-Bundle::Common"
#	$(call bundle_install,"Bundle::Evaluation" )
	make "install-Bundle::Evaluation"

install-%:
	export THIRD_PARTY_PERL_ROOT=$(CURDIR)/../local/ && export HOME=$(CURDIR) && export PERL5LIB="$(CURDIR)/.cpan/:$(CURDIR):$(CURDIR)/../local/lib/" && export CPAN_BUILD_ROOT=`mktemp -d` && perl -MCPAN -e "install $*"

build_clean:
	rm -rf $(CURDIR)/../local/.cpan/build/*

clean:
	@rm -rf *~
