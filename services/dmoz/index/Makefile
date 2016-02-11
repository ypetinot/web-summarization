DMOZ_RDF_URL=http://rdf.dmoz.org/rdf/
DMOZ_DATA_ARCHIVE=content.rdf.u8.gz
DMOZ_DATA_FILE=content.rdf.u8
DMOZ_DATA_FILE_EN="${DMOZ_DATA_FILE}.en"
DMOZ_INDEX=index

default: ${DMOZ_INDEX}

${DMOZ_INDEX}: ${DMOZ_DATA_FILE_EN}
	echo "creating index ..."
	cat ${DMOZ_DATA_FILE_EN} | java dmozindexer.Indexer

${DMOZ_DATA_FILE}:
	wget "${DMOZ_RDF_URL}/${DMOZ_DATA_ARCHIVE}"
	gunzip ${DMOZ_DATA_FILE}

${DMOZ_DATA_FILE_EN}: ${DMOZ_DATA_FILE}
	@echo "Creating English DMOZ dataset ..."
	cat ${DMOZ_DATA_FILE} | generate-description-data | dmoz-filter-en > ${DMOZ_DATA_FILE_EN}

clean:
	rm -rf ${DMOZ_DATA_FILE}
	rm -rf ${DMOZ_DATA_FILE_EN}
	rm -rf ${DMOZ_DATA_ARCHIVE}
	rm -rf index
	rm -rf *~
