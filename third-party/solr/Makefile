SOLR_ARCHIVE_URL=http://mirror.cc.columbia.edu/pub/software/apache/lucene/solr/4.7.2/solr-4.7.2.tgz
SOLR_ARCHIVE_FILE=$(notdir $(SOLR_ARCHIVE_URL))
SOLR_ARCHIVE_DIR=$(patsubst %.tgz, %, $(SOLR_ARCHIVE_FILE))

TOMCAT_ROOT:=$(CURDIR)/../tomcat/tomcat-root/
TOMCAT_WEBAPPS:=$(TOMCAT_ROOT)/webapps/
TOMCAT_LIB:=$(TOMCAT_ROOT)/lib/
TOMCAT_CONF:=$(TOMCAT_ROOT)/conf/
TOMCAT_SOLR:=$(TOMCAT_ROOT)/solr

CATALINA_LOCALHOST_ROOT:=$(TOMCAT_CONF)/Catalina/localhost/

# TODO: CURDIR should really be the directory in which this makefile sits
COLLECTIONS:=$(shell find $(CURDIR)/collections/ -mindepth 1 -maxdepth 1 -type d -not -name '.*' | tr '\n' ' ')
#COLLECTIONS_CONF:=$(foreach collection_id,$(COLLECTIONS),$(CATALINA_LOCALHOST_ROOT)/$(notdir $(collection_id)).xml)
SOLR_CONTEXT_TEMPLATE:=solr.conf
SOLR_CONTEXT:=$(CATALINA_LOCALHOST_ROOT)/solr.xml
COLLECTION_CONF_TEMPLATE:=collection.template.conf
WEB_INF_LIB:=WEB-INF/lib/

default: $(SOLR_CONTEXT) solr-deploy

$(SOLR_ARCHIVE_FILE):
	wget -O $@ $(SOLR_ARCHIVE_URL)

$(WEB_INF_LIB):
	mkdir -p $@

solr-deploy: $(WEB_INF_LIB) $(SOLR_ARCHIVE_DIR)
#	cp $(SOLR_ARCHIVE_DIR)/dist/*.war $(TOMCAT_WEBAPPS)
	cp $(SOLR_ARCHIVE_DIR)/dist/*.jar $(WEB_INF_LIB)
#	cp -rf $(SOLR_ARCHIVE_DIR)/dist/solrj-lib/*slf4j*.jar $(TOMCAT_LIB)	
#	cp -rf $(SOLR_ARCHIVE_DIR)/dist/solrj-lib/log4j*.jar $(TOMCAT_LIB)
#	cp -rf $(SOLR_ARCHIVE_DIR)/dist/solrj-lib/commons-*.jar $(TOMCAT_LIB)
#	cp -rf $(SOLR_ARCHIVE_DIR)/dist/solrj-lib/http*.jar $(TOMCAT_LIB)
	cp -rf $(SOLR_ARCHIVE_DIR)/dist/solrj-lib/*.jar $(TOMCAT_LIB)
#	cp solr.xml $(TOMCAT_CONF)

$(TOMCAT_SOLR): solr-deploy

$(CATALINA_LOCALHOST_ROOT): $(TOMCAT_SOLR)
	mkdir -p $@

###$(CATALINA_LOCALHOST_ROOT)/%.xml: $(CATALINA_LOCALHOST_ROOT) $(COLLECTION_CONF_TEMPLATE)
###	#-ln -s collections/$* $*
###	cat $(COLLECTION_CONF_TEMPLATE) | sed 's#__PATH_SEGMENT_HOME__#$(CURDIR)/collections/$*#' | sed 's#__COLLECTION_ID__#$*#' > $@

$(SOLR_CONTEXT): $(SOLR_CONTEXT_TEMPLATE) $(CATALINA_LOCALHOST_ROOT)
	cat $< | sed 's#__SOLR_BASE__#$(CURDIR)/#g' > $@

$(SOLR_ARCHIVE_DIR): $(SOLR_ARCHIVE_FILE)
	tar xzf $(SOLR_ARCHIVE_FILE)
	rm -rf $@/example/

clean:
	rm -rf *~
	rm -rf $(SOLR_ARCHIVE_FILE) $(SOLR_ARCHIVE_DIR)
