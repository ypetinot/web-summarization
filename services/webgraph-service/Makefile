#WEBGRAPH_POM_URL=http://search.maven.org/remotecontent?filepath=it/unimi/dsi/webgraph-big/3.3.5/webgraph-big-3.3.5.pom

# Maven repository : http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22it.unimi.dsi%22
# http://search.maven.org/remotecontent?filepath=it/unimi/dsi/webgraph-big/3.3.5/webgraph-big-3.3.5.jar

# maven java source: http://stackoverflow.com/questions/9752972/how-to-add-an-extra-source-directory-for-maven-to-compile-and-include-in-the-bui
# maven dependencies: http://stackoverflow.com/questions/23443444/can-not-find-logback-xml-in-resources-folder

default: gen-java thrift-install-perl-libs
	# -X for debug mode
	mvn install

.PHONY: clean
clean: clean-service
	mvn clean
	rm -rf *~
#	rm -rf $(CURDIR)/target/

include $(CURDIR)/../makefile.service
