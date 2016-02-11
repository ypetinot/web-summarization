# Makefile for libMSA
SRC=$(shell find . -maxdepth 1 -name '*.cc')
OBJ=$(patsubst %.cc,%.o,$(SRC))

FLAGS=-fPIC -g

CFLAGS=$(FLAGS) -fPIC

CC=g++

LIB_MSA=libMSA.so

TEMPLATE_GENERATOR=template_generator

INCLUDE=-I ${CURDIR}/../../third-party/local/include/ -I ${CURDIR}/../../third-party/google/protobuf-2.3.0/src/
LIBS=-L ${CURDIR}/../../third-party/local/lib/ -lgflags -lglog -lprotobuf -lboost_serialization

default: $(LIB_MSA) $(TEMPLATE_GENERATOR)

.PHONY: clean

$(LIB_MSA): $(OBJ)
	$(CC) $(FLAGS) $(LIBS) -shared -o $@ $^

$(TEMPLATE_GENERATOR): $(TEMPLATE_GENERATOR).o $(LIB_MSA)
	$(CC) $(FLAGS) $(LIBS) -L. -lMSA $< -o $@

%.o: %.cc
	$(CC) $(CFLAGS) $(INCLUDE) -o $@ -c $< 

clean:
	rm -rf *~
	rm -rf ${OBJ}
	rm -rf ${LIB_MSA}
