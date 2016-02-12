default: boost
	export BOOST_DIR=`find ./ -maxdepth 1 -type d | grep boost` && cd ${BOOST_DIR} && ./bootstrap.sh --prefix=${CURDIR}/../local/ && export BOOST_BUILD_PATH=${CURDIR}/${BOOST_DIR}/ && ./bjam install

boost:
	apt-get -b source libboost-dev


clean:
	rm -rf *~
	rm -rf ${BOOST_DIR}
