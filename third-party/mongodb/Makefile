#MONGODB_ARCHIVE_URL=http://fastdl.mongodb.org/src/mongodb-src-r2.6.6.tar.gz
MONGODB_ARCHIVE_URL=http://fastdl.mongodb.org/src/mongodb-src-r2.6.9.tar.gz
MONGODB_ARCHIVE=$(notdir ${MONGODB_ARCHIVE_URL})
MONGODB_DIRECTORY=$(patsubst %.tar.gz,%,$(MONGODB_ARCHIVE))

default: $(MONGODB_DIRECTORY)

$(MONGODB_DIRECTORY): $(MONGODB_ARCHIVE)
	tar xzf *.tar.gz && cd $(MONGODB_DIRECTORY) && scons --prefix=${PWD} install
#install mongodb-linux-*/bin/* ${CURDIR}/../local/bin/ 

$(MONGODB_ARCHIVE):
	wget -O $@ $(MONGODB_ARCHIVE_URL)

# TODO : I would also need to remove the mongodb binaries that get copied to $(CURDIR)'s "bin" directory
clean:
	rm -rf ${MONGODB_DIRECTORY} ${MONGODB_ARCHIVE}
	rm -rf *~
