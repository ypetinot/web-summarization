WEKA_ARCHIVE_URL=http://prdownloads.sourceforge.net/weka/weka-3-7-11.zip
WEKA_ARCHIVE_FILE=$(notdir $(WEKA_ARCHIVE_URL))
WEKA_ARCHIVE_DIR=$(patsubst %.zip, %, $(WEKA_ARCHIVE_FILE))

default: $(WEKA_ARCHIVE_DIR)

$(WEKA_ARCHIVE_FILE):
	wget -O $@ $(WEKA_ARCHIVE_URL)

$(WEKA_ARCHIVE_DIR): $(WEKA_ARCHIVE_FILE)
	unzip $(WEKA_ARCHIVE_FILE)

clean:
	rm -rf *~
	rm -rf $(WEKA_ARCHIVE_FILE) $(WEKA_ARCHIVE_DIR)
