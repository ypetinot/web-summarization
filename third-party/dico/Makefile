define _generate_package_building_rules

# TODO : to be generated automatically
PACKAGE_NAME=$(2)

$(PACKAGE_NAME)_ARCHIVE_URL=$(1)
$(PACKAGE_NAME)_ARCHIVE=$$(notdir $$($(PACKAGE_NAME)_ARCHIVE_URL))
$(PACKAGE_NAME)_DIRECTORY=$$(patsubst %.tar.gz,%,$$($(PACKAGE_NAME)_ARCHIVE))

default: $$($(PACKAGE_NAME)_DIRECTORY)

$$($(PACKAGE_NAME)_DIRECTORY): $$($(PACKAGE_NAME)_ARCHIVE)
	tar xzf *.tar.gz && cd $$@ && ./configure --prefix=$${PWD} && make

$$($(PACKAGE_NAME)_ARCHIVE):
	wget -O $$@ $$($(PACKAGE_NAME)_ARCHIVE_URL)

clean:
	rm -rf $${$(PACKAGE_NAME)_DIRECTORY} $${$(PACKAGE_NAME)_ARCHIVE}
	rm -rf *~

endef

PACKAGE_NAME=dico
DICO_ARCHIVE_URL=ftp://download.gnu.org.ua/pub/release/dico/dico-2.2.tar.gz
$(eval $(call _generate_package_building_rules,$(DICO_ARCHIVE_URL),$(PACKAGE_NAME)))
