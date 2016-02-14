# Makefile for libHierchicalSummarization
BUILDER_SRC=hierarchy_builder.cc
LIB_HIERARCHY_SRC=$(shell find . -maxdepth 1 -name '*.cc' | grep -v $(BUILDER_SRC))

BUILDER_OBJ:=$(patsubst %.cc,%.o,$(BUILDER_SRC))
LIB_HIERARCHY_OBJ=$(patsubst %.cc,%.o,$(LIB_HIERARCHY_SRC))

#FLAGS=-fPIC -g
FLAGS=-g

#CFLAGS=$(FLAGS) -fPIC

CC=g++
BUILDER=confusius-tm-build

#LIB_HIERARCHY=libhierarchy.so
#LIB_HIERARCHY_LFLAGS=-L$(CURDIR) -lhierarchy

INCLUDE=-I ${CURDIR}/../../../third-party/local/include/ -I ${CURDIR}/../../../third-party/google/protobuf-2.3.0/src/
#LIBS=-L ${CURDIR}/../../../third-party/local/lib/ -lgflags -lglog -lprotobuf -lboost_serialization
LIBS=-L ${CURDIR}/../../../third-party/local/lib/ -l libgflags.a -l libglog.a -l libprotobuf.a -l libboost_serialization.a

default: $(LIB_HIERARCHY) $(BUILDER)

.PHONY: clean support

#$(BUILDER): $(BUILDER_OBJ) $(LIB_HIERARCHY)
$(BUILDER): $(BUILDER_OBJ) $(LIB_HIERARCHY_OBJ)
	$(CC) $(FLAGS) $(LIBS) $(LIB_HIERARCHY_LFLAGS) -static -o $@ $(BUILDER_OBJ) $(LIB_HIERARCHY_OBJ)

$(LIB_HIERARCHY): $(LIB_HIERARCHY_OBJ)
	$(CC) $(FLAGS) $(LIBS) -shared -o $@ $^

%.o: %.cc
	$(CC) $(CFLAGS) $(INCLUDE) -o $@ -c $< 

clean:
	rm -f *.o *~
	rm -f ${BUILDER} ${LIB_HIERARCHY}
