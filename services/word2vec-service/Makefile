WORD2VEC_SERVICE_THRIFT=$(CURDIR)/word2vec_service.thrift

THRIFT_GEN_CPP=gen-cpp
THRIFT_GEN_PERL=gen-perl
THRIFT_GEN=$(THRIFT_GEN_CPP) $(THRIFT_GEN_PERL)

TARGET_CLIENT=word2vec-client
TARGET_SERVER=word2vec-server
TARGETS=thrift-install-perl-libs $(TARGET_SERVER)

default: $(TARGETS)

include $(CURDIR)/../makefile.service

THIRD_PARTY_LOCAL=$(THIRD_PARTY_BASE)/local/
THIRD_PARTY_INCLUDE=$(THIRD_PARTY_LOCAL)/include/
THIRD_PARTY_LIB=$(THIRD_PARTY_LOCAL)/lib/
THRIFT_BASE_CPP=$(THRIFT_BASE)/thrift-0.9.2/lib/cpp/
THRIFT_INCLUDE=$(THRIFT_BASE_CPP)/src/
THRIFT_LIB=$(THRIFT_BASE_CPP)/.libs/
THRIFT_ADDITIONAL_BASE=$(THRIFT_INCLUDE)/thrift/
THRIFT_ADDITIONAL=$(foreach test,TApplicationException Thrift concurrency/Monitor concurrency/Mutex concurrency/ThreadManager concurrency/PosixThreadFactory concurrency/TimerManager concurrency/Util server/TNonblockingServer server/TSimpleServer server/TThreadedServer server/TThreadPoolServer transport/TBufferTransports transport/TServerSocket transport/TSocket transport/TTransportException,$(THRIFT_ADDITIONAL_BASE)/$(test).o)

THRIFT_SERVER_SRC=$(CURDIR)/src/c++/word2vec_server.cpp
THRIFT_SERVER_CFLAGS=$(GOOGLE_SPARSEHASH_INCLUDE)

# TODO : is there a better solution to automatically generate the dependencies from cpp files ?
THRIFT_GEN_BASE=Word2Vec word2vec_service_constants word2vec_service_types
THRIFT_GEN_SRC=$(foreach thrift_gen_base,$(THRIFT_GEN_BASE),$(THRIFT_GEN_CPP)/$(thrift_gen_base).cpp)

SRC=$(THRIFT_SERVER_SRC) $(THRIFT_GEN_SRC)
OBJ=$(patsubst %.cpp,%.o,$(SRC))

# TODO : make modifications so that both the optimized and debug versions can be built
DEBUG_FLAGS=-g
%.o: %.cpp
	g++ -c -I $(THIRD_PARTY_INCLUDE) -I $(THRIFT_INCLUDE) -O5 $< -o $@

$(THRIFT_SERVER_SRC): $(THRIFT_GEN_SRC) $(THRIFT_GEN_HEADER)

# TODO: how to get the full list of prerequisites ?
$(TARGET_SERVER): $(OBJ) $(THRIFT_ADDITIONAL)
	g++ -L $(THIRD_PARTY_LIB) -lboost_regex -L $(THRIFT_LIB) -lthrift -lthriftz $^ -lpthread -levent -o $@

# TODO : add thrift to PATH variable
# TODO : reduce recipe duplication for code generation
$(THRIFT_GEN_SRC) $(THRIFT_GEN_HEADER): $(THRIFT_GEN_CPP)

###$(THRIFT_GEN_CPP): $(WORD2VEC_SERVICE_THRIFT)
###	$(CURDIR)/../../third-party/local/bin/thrift --gen cpp $<

###$(THRIFT_GEN_PERL): $(WORD2VEC_SERVICE_THRIFT)
###	$(CURDIR)/../../third-party/local/bin/thrift --gen perl $<

clean:
	rm -f $(OBJ) $(TARGETS)
	rm -rf $(THRIFT_GEN) $(TRHIFT_GEN_PERL)
	rm -f *~

# Note : no dependency on the original code
#trunk:
#	svn checkout http://word2vec.googlecode.com/svn/trunk/
