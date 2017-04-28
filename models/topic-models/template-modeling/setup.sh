#!/bin/bash

# TODO : Must stop on the first error
set -e error

# install required packages
# TODO : read list from separate file
apt-get -y install g++ libdsfmt-dev libgflags-dev libgsl0-dev libgoogle-glog-dev libsparsehash-dev libboost-dev
