MODULES_SRC=viterbi_decoder.cc LanguageModel.cc LanguageModel_Ngram.cc LanguageModel_SRILM.cc TranslationModel.cc TranslationModel_IBM_Model1.cc TokenSequence.cc ProbabilisticTokenSequence.cc main.cc
MODULES_OBJ=$(patsubst %.cc,%.o,$(MODULES_SRC))
TARGET_OCELOT_3=ocelot-3

INCLUDES=-I${CURDIR}/../../../third-party/local/include/ -I${CURDIR}/../../../third-party/smt/giza-pp/GIZA++-v2/
#LIBS=-L${CURDIR}/../../../third-party/local/lib/i686 -loolm -lmisc -lflm -ldstruct
#LIBS=-L${CURDIR}/../../../third-party/lm/srilm/lib/i686-gcc4/ -loolm -lmisc -lflm -ldstruct
LIBS=-L${CURDIR}/../../../third-party/lm/srilm/lib/i686-m64/ -loolm -lmisc -lflm -ldstruct
LIBS+=-L${CURDIR}/../../../third-party/local/lib/ -lboost_program_options
CFLAGS=-DWORDINDEX_WITH_4_BYTE -DNDEBUG -g

GIZAPP_OBJ=${CURDIR}/../../../third-party/smt/giza-pp/GIZA++-v2/optimized/TTables.o ${CURDIR}/../../../third-party/smt/giza-pp/GIZA++-v2/optimized/Parameter.o ${CURDIR}/../../../third-party/smt/giza-pp/GIZA++-v2/optimized/vocab.o

#${CURDIR}/../../../third-party/smt/giza-pp/GIZA++-v2/optimized/model1.o

default: ${TARGET_OCELOT_3}

${TARGET_OCELOT_3}: ${MODULES_OBJ}
	g++ -o ${TARGET_OCELOT_3} ${MODULES_OBJ} ${GIZAPP_OBJ} ${LIBS}

%.o: %*.cc
	g++ ${INCLUDES} -c $< -o $*.o ${CFLAGS}

clean:
	rm -rf ${TARGET_OCELOT_3}
	rm -rf *.o *~
