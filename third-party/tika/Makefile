TIKA_APP_JAR_URL=http://mirror.cc.columbia.edu/pub/software/apache/tika/tika-app-1.6.jar
TIKA_SRC_URL=http://mirror.cc.columbia.edu/pub/software/apache/tika/tika-1.6-src.zip
TIKA_APP_JAR=$(notdir $(TIKA_APP_JAR_URL))
TIKA_ARCHIVE=$(notdir $(TIKA_SRC_URL))
TIKA_DIRECTORY=$(patsubst %-src.zip,%,$(TIKA_ARCHIVE))

default: $(TIKA_DIRECTORY)

$(TIKA_JAR):
	wget -O $@ $(TIKA_URL)

$(TIKA_ARCHIVE):
	wget -O $@ $(TIKA_SRC_URL)

$(TIKA_DIRECTORY): $(TIKA_ARCHIVE)
	unzip -u $< && cd $@ && mvn verify

clean:
	rm -rf *~
	rm -rf $(TIKA_DIRECTORY)
	rm -rf $(TIKA_ARCHIVE)
