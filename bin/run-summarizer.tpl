
USAGE="Usage: $0 SUMMARIZER CONTEXT";

while getopts ":s:w:" options; do
  case $options in
    s ) SENTENCES=$OPTARG; shift;;
    w ) WORDS=$OPTARG; shift;;
    h ) echo $USAGE;;
    \? ) echo $USAGE
         exit 1;;
    * ) echo $USAGE
         exit 1;;
  esac
done

# check number of parameters
if [ $# -lt 2 ]; then
        echo $USAGE;
	exit;
fi

# get parameters
SUMMARIZER=$1
CONTEXT=$2

# source base environment
. ${CONTEXT_SUMMARIZATION_ROOT}/setenv > /dev/null

# source common environment
. ${CONTEXT_SUMMARIZATION_COMMON_ROOT}/setenv > /dev/null

# source target summarizer's environment
. ${CONTEXT_SUMMARIZATION_ROOT}/${SUMMARIZER}/setenv > /dev/null

# set root for all temp files
if [ -f ${CONTEXT} ]; then
	export _DATADIR=`dirname ${CONTEXT}`;
        export _ABSOLUTE_DATADIR=`readlink -f ${_DATADIR}`
        export TMPDIR=${_ABSOLUTE_DATADIR}/tmp/;
        mkdir -p ${TMPDIR}
fi
 
# actually run target summarizer
if [ $WORDS ]; then
	#OPTIONS="--words=${WORDS}"
	OPTIONS="-w${WORDS}"
else
	#OPTIONS="--sentences=${SENTENCES}"
	OPTIONS="-s${SENTENCES}"
fi
#echo "will use ${OPTIONS}";
${CONTEXT_SUMMARIZATION_ROOT}/$1/bin/${SUMMARIZER} ${OPTIONS} ${TARGET} ${CONTEXT}
