SCALA_URL=http://downloads.typesafe.com/scala/2.11.7/scala-2.11.7.tgz
SCALA_ARCHIVE=$(notdir $(SCALA_URL))
SCALA_DIRECTORY=$(patsubst %.tgz,%,$(SCALA_ARCHIVE))

default: $(SCALA_DIRECTORY)

$(SCALA_DIRECTORY): $(SCALA_ARCHIVE)
	tar xzf $<

$(SCALA_ARCHIVE):
	wget -O $@ $(SCALA_URL)

clean:
	rm -rf $(SCALA_ARCHIVE) $(SCALA_DIRECTORY)
	rm -f *~
