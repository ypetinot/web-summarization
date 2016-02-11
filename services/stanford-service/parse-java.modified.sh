#!/bin/bash

CMD="java -cp $CLASSPATH:stanford-corenlp-wrapper.jar org.ets.research.nlp.stanford_thrift.StanfordCoreNLPClient"

if [ $# -eq 3 ]; then
    SERVER=$1
    PORT=$2
    INFILE=$3
    $CMD $SERVER $PORT $INFILE
else
    echo "Usage: parse-java.sh <server> <port> [<inputfile>]"
fi
