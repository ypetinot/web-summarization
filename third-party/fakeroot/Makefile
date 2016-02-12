default: fakeroot

fakeroot-distro:
	apt-get source fakeroot
	find ./ -maxdepth 1 -type d -name 'fake*' -exec ln -s {} $@ \;

fakeroot: fakeroot-distro
	cd $< && ./configure --prefix=${CURDIR}/../local/ && make && make install && cd ..

clean:
	rm -rf *~
	rm -rf fakeroot*