#TODO: move recipe to shared makefile

INSTALL_DIRECTORY=$(CURDIR)/../../local/

# URL of tarball to download and instance
GLPK_URL:=http://ftp.gnu.org/gnu/glpk/glpk-4.53.tar.gz

PACKAGE_URLS=$(GLPK_URL)
package_target=installed-package-$(shell echo $1 | md5sum | awk '{ print $$1 }')
TARGETS=$(foreach url,$(GLPK_URL),$(call package_target,$(url)))

.PHONY:default
default:

# called as ( URL )
# TODO: turn recipe into one-liner so that I don't have to specify download file as a parameter
define package_dbi

#BUILD_CONFIRMATION:=installed-package-$(shell echo $1 | md5sum | awk '{ print $$1 }')
BUILD_CONFIRMATION:=$(call package_target,$1)
BUILD_CONFIRMATION_FILES += $$(BUILD_CONFIRMATION)
$$(warning BUILD_CONFIRMATION: $$(BUILD_CONFIRMATION))

DOWNLOAD_FILE:=$(lastword $(subst /, ,$1))
$$(warning DOWNLOAD_FILE: $$(DOWNLOAD_FILE))

BUILD_DIRECTORY=$$(patsubst %.tar.gz,%,$$(DOWNLOAD_FILE))
$$(warning BUILD_DIRECTORY: $$(BUILD_DIRECTORY))

# download rule
$$(DOWNLOAD_FILE):
	@echo "Downloading $1 ..."
	wget -O $$@ $1
	@echo "Done downloading"

# expand rule
$$(BUILD_DIRECTORY): $$(DOWNLOAD_FILE)
	@echo "Expanding $$< ..."
	tar xzf $$<

# build/install rule
$$(BUILD_CONFIRMATION): $$(BUILD_DIRECTORY)
	@echo "Building $1 ..."
	cd $$< && ./configure --prefix=$2 && make install
	touch $$@

#TODO: how do we turn something like this into a canned recipe ?
clean:
	rm -rf *~
	rm -rf $$(BUILD_DIRECTORY)
	rm -rf $$(DOWNLOAD_FILE)
	rm -rf $$(BUILD_CONFIRMATION)

endef

$(eval $(call package_dbi,$(GLPK_URL),$(INSTALL_DIRECTORY)))

#.PHONY:default
$(warning Confirmation files: $(BUILD_CONFIRMATION_FILES))
default: $(BUILD_CONFIRMATION_FILES)
	echo "Done"