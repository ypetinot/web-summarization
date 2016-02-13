# Note : currently no way to automate download, must manually download archive first
OPENJDK_URL=http://download.oracle.com/otn-pub/java/jdk/8u25-b17/jdk-8u25-linux-x64.tar.gz
OPENJDK_LOCAL_ARCHIVE=$(CURDIR)/../../../../../../third-party-distributions/jdk-8u25-linux-x64.tar.gz
OPENJDK_ARCHIVE=$(notdir $(OPENJDK_URL))
#OPENJDK_DIRECTORY=$(patsubst %.tar.gz,%,$(OPENJDK_ARCHIVE))
OPENJDK_DIRECTORY=jdk1.8.0_25
JAVA_BIN_DIRECTORY=bin
JAVA_LIB_DIRECTORY=lib

default: $(JAVA_BIN_DIRECTORY) $(JAVA_LIB_DIRECTORY)

$(JAVA_BIN_DIRECTORY) $(JAVA_LID_DIRECTORY): $(OPENJDK_DIRECTORY)
	ln -s $(OPENJDK_DIRECTORY)/bin/
	ln -s $(OPENJDK_DIRECTORY)/lib/

$(OPENJDK_DIRECTORY): $(OPENJDK_ARCHIVE)
	tar xzf $<
	touch $@

$(OPENJDK_ARCHIVE): $(OPENJDK_LOCAL_ARCHIVE)
	#wget -O $@ $(OPENJDK_URL)
	cp $< $@

clean:
	rm -rf *~
	rm -f $(JAVA_BIN_DIRECTORY) $(JAVA_LIB_DIRECTORY)
	rm -rf $(OPENJDK_ARCHIVE) $(OPENJDK_DIRECTORY)
