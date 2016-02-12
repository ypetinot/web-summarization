# TODO : Tomcat 8.0 not a real release at this time (?), sticking with 7.0 for now.
#TOMCAT_ARCHIVE_URL=http://www.motorlogy.com/apache/tomcat/tomcat-8/v8.0.3/src/apache-tomcat-8.0.3-src.tar.gz
TOMCAT_ARCHIVE_URL=http://mirror.cc.columbia.edu/pub/software/apache/tomcat/tomcat-7/v7.0.53/src/apache-tomcat-7.0.53-src.tar.gz
ARCHIVE_FILE=$(notdir $(TOMCAT_ARCHIVE_URL))
ARCHIVE_DIR=$(patsubst %.tar.gz,%,$(ARCHIVE_FILE))

TARGET:=$(CURDIR)/tomcat
TOMCAT_ROOT_LINK:=tomcat-root
TOMCAT_BUILD_ROOT:=${TARGET}/build/

default: $(TOMCAT_ROOT_LINK)

$(TOMCAT_BUILD_ROOT): $(TARGET)

$(TOMCAT_ROOT_LINK): $(TOMCAT_BUILD_ROOT)
	ln -s $< $@

.DELETE_ON_ERROR:
$(ARCHIVE_FILE):
	wget -O $@ $(TOMCAT_ARCHIVE_URL)

$(ARCHIVE_DIR): $(ARCHIVE_FILE)
	tar xzf $<

$(TARGET): $(ARCHIVE_DIR)
	cat $</build.properties.default | sed 's|^base.path=\(.*\)$$|base.path=$(TARGET)|' > $</build.properties
	echo "tomcat.output=$(TARGET)" >> $</build.properties
	cp web.xml $</conf/
	cp server.xml $</conf/
	cp tomcat-users.xml $</conf/
	cd $< && ant deploy && cd ..

clean:
	rm -rf *~ *.tar.gz
	rm -rf $(ARCHIVE_FILE) $(ARCHIVE_DIR) $(TARGET)
	rm -rf $(TOMCAT_ROOT_LINK)
