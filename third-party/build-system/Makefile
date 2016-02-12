MAVEN=maven
MAVEN_URL=http://www.carfab.com/apachesoftware/maven/maven-3/3.2.3/binaries/apache-maven-3.2.3-bin.tar.gz
MAVEN_DIR=apache-maven-3.2.3

.PHONY:clean

$(MAVEN):
	mkdir $(MAVEN)
	cd $(MAVEN) && wget $(MAVEN_URL) && tar xzf *.tar.gz

clean:
	rm -rf *~ $(MAVEN)
