GSL_URL=http://ftp.jaist.ac.jp/pub/GNU/gsl/gsl-1.15.tar.gz
GSL_FILE=$(lastword $(subst /, , $(GSL_URL)))
GSL_DIR=$(patsubst %.tar.gz,%,$(GSL_FILE))
GSL_TARGET=gsl.installed

$(GSL_TARGET): $(GSL_FILE)
	tar xzf $(GSL_FILE)
	cd $(GSL_DIR) && ./configure --prefix=$(CURDIR)/../local/ && make install && cd $(CURDIR)
	touch $(GSL_TARGET)

$(GSL_FILE):
	wget -O $(GSL_FILE) $(GSL_URL)

clean:
	rm -rf *~
	rm -rf $(GSL_FILE)
	rm -rf $(GSL_DIR)
	rm -rf $(GSL_TARGET)
