INCLUDES = -I $(CURDIR)/../../../third-party/local/include/
CC = g++
LDFLAGS = -L$(CURDIR)/../../../third-party/local/lib/
LIBRARIES = -lglog -lgflags -lpthread -lboost_serialization -lprotobuf -lgsl -lgslcblas
EXECUTABLES = template-training
MTFLAGS = -msse2 -DDSFMT_MEXP=521 -DHAVE_SSE2 --param max-inline-insns-single=1800 --param inline-unit-growth=500 --param large-function-growth=900
#CFLAGS = -O3 $(MTFLAGS)  -DUSE_MT_RANDOM
CFLAGS = -g $(MTFLAGS)  -DUSE_MT_RANDOM
COMPILE = $(CC) $(CFLAGS) $(INCLUDES)
LINK = $(CC) $(CFLAGS)

all: $(EXECUTABLES)

#dSFMT.o: $(CURDIR)/../../../third-party/dsFMT/dsFMT/dSFMT.c
#	$(COMPILE) -c $< -o dSFMT.o

%.o: %.cc
	$(COMPILE) -c $< -o $@

OBJECTS=parameters.o probabilistic_object.o gappy_pattern.o corpus.o template.o gist.o tree.o template_modeling.o template_sampler.o template_element.o template_slot.o statistics.o dirichlet_process.o distribution.o poisson_distribution.o
#gappy_pattern_process.o
#dSFMT.o
#object.o => where did this use to come from ?

template-training: $(OBJECTS)

	$(LINK) $^ -o $@ $(LDFLAGS) $(LIBRARIES)

clean:
	-rm -f *.o *.so *.pyc *~ 
	-rm -f $(EXECUTABLES)

deepclean: clean
	-rm -f *.o
