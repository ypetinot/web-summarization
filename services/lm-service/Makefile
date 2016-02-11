# TODO : currently we need to source dist.rc => how can we fix this elegantly ?

LM_SERVICE_THRIFT=$(CURDIR)/lm_service.thrift

TARGET_SERVER=lm-server
TARGETS=gen-cpp $(TARGET_SERVER) thrift-install-perl-libs

default: $(TARGETS)

include $(CURDIR)/../makefile.service

THRIFT_SERVER_SRC=$(CURDIR)/src/c++/lm_server.cpp
THRIFT_SERVER_CFLAGS=$(GOOGLE_SPARSEHASH_INCLUDE)

# TODO : is there a better solution to automatically generate the dependencies from cpp files ?
THRIFT_CPP_GEN_BASE=LMService lm_service_constants lm_service_types
THRIFT_CPP_GEN_SRC=$(foreach thrift_cpp_gen_base,$(THRIFT_CPP_GEN_BASE),$(THRIFT_CPP_GEN)/$(thrift_cpp_gen_base).cpp)

SRC=$(THRIFT_SERVER_SRC) $(THRIFT_CPP_GEN_SRC)
OBJ=$(patsubst %.cpp,%.o,$(SRC))

$(THRIFT_SERVER_SRC): $(THRIFT_CPP_GEN_SRC)

# TODO: how to get the full list of prerequisites ?
$(TARGET_SERVER): $(OBJ) $(THRIFT_CPP_ADDITIONAL)
	g++ -L $(THIRD_PARTY_LIB) -lboost_regex -L $(THRIFT_CPP_LIB) -lthrift -lthriftz $^ -lpthread -o $@

# TODO : add thrift to PATH variable
# TODO : reduce recipe duplication for code generation
$(THRIFT_GEN_SRC): $(THRIFT_GEN_CPP)

clean: clean-service
	rm -f $(OBJ) $(TARGETS)
	rm -rf $(TRHIFT_GEN_PERL)
	rm -f *~
