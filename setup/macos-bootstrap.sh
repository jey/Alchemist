#!/bin/bash
set -o verbose
set -o errexit

# This script installs the prerequisites for building Alchemist on MacOS 
# (tested on Sierra)

# How to use this script:
#
#   go to the directory that will serve as the alchemist root directory
#   git clone https://github.com/alexgittens/alchemist.git
#   bash ./alchemist/setup/macos-bootstrap.sh

ALROOT=$PWD
ALPREFIX=$ALROOT/bins

# Set the following flags to indicate what needs to be installed
WITH_BREW_PREREQS=0
WITH_EL=0
WITH_RANDOM123=0
WITH_HDF5=0
WITH_SKYLARK=1
WITH_ARPACK=1
WITH_ARPACKPP=1
WITH_EIGEN=1
WITH_SPDLOG=1

# Check that the cmake toolchain file for Skylark is where we expect
TOOLCHAIN=$ALROOT/alchemist/setup/MacOS-g++.cmake
[ -f "$TOOLCHAIN" ]

# install brewable prereqs if not already there
# TODO: really don't like installing brew packages w/ nonstandard compiler, but works for now
# try to replace those brew calls with explicit builds managed in the booststrap script 
if [ $WITH_BREW_PREREQS = 1 ]; then
  xcode-select --install
  brew install gcc
  brew install make --with-default-names
  brew install cmake
  brew install boost --cc=gcc-7
  brew install boost-mpi --cc=gcc-7
  brew install sbt
  brew install gmp
  brew install fftw
  brew install zlib
  brew install szlib
fi

export CC="gcc-7"
export CXX="g++-7"
export FC="gfortran-7"

# Start download auxiliary packages
mkdir -p $ALPREFIX
mkdir -p dl
cd dl

# Elemental
if [ "$WITH_EL" = 1 ]; then
  if [ ! -d Elemental ]; then
    git clone https://github.com/elemental/Elemental
  fi
  cd Elemental
  git checkout v0.87.4
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DEL_IGNORE_OSX_GCC_ALIGNMENT_PROBLEM=ON \
    -DCMAKE_INSTALL_PREFIX=$ALPREFIX ..
  nice make -j8
  make install
  cd ../..
fi

# Random123
if [ "$WITH_RANDOM123" = 1 ]; then
  if [ ! -d Random123-1.08 ]; then
    curl -L http://www.thesalmons.org/john/random123/releases/1.08/Random123-1.08.tar.gz > Random123-1.08.tar.gz
    tar xvfz Random123-1.08.tar.gz
  fi
  cp -rf Random123-1.08/include/Random123 $ALPREFIX/include
fi

# HDF5
# TODO: figure out how to use CMAKE so it can detect zlib and szip
# for now, have to manually update the library paths in the install code if versions of packages change
# the include and lib for the szlib and zlib packages were obtained using brew ls 'package'
if [ "$WITH_HDF5" = 1 ]; then
	if [ ! -d hdf5-1.10.1 ]; then
		curl -L https://support.hdfgroup.org/ftp/HDF5/current/src/hdf5-1.10.1.tar > hdf5-1.10.1.tar
		tar xzf hdf5-1.10.1.tar
	fi
	cd hdf5-1.10.1
	./configure --prefix="$ALPREFIX" \
		--enable-cxx \
		--enable-java \
		--enable-fortran \
		--with-zlib=/usr/local/opt/zlib/include,/usr/local/opt/zlib/lib \
		--with-szlib=/usr/local/Cellar/szip/2.1.1/include/,/usr/local/Cellar/szip/2.1.1/lib/
	nice make -j8
	make install
fi

# Skylark
if [ "$WITH_SKYLARK" = 1 ]; then
  if [ ! -d libskylark ]; then
    git clone https://github.com/xdata-skylark/libskylark.git
  fi
  cd libskylark
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  export ELEMENTAL_ROOT="$ALPREFIX"
  export RANDOM123_ROOT="$ALPREFIX"
	export HDF5_ROOT=$ALPREFIX
  CXXFLAGS="-dynamic -std=c++14 -fext-numeric-literals" cmake \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_INSTALL_PREFIX="$ALPREFIX" \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DUSE_HYBRID=OFF \
    -DUSE_FFTW=ON \
    -DBUILD_PYTHON=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_EXAMPLES=ON ..
  VERBOSE=1 nice make -j16
  make install
  cd ../..
fi

# arpack-ng
if [ "$WITH_ARPACK" = 1 ]; then
  if [ ! -d arpack-ng ]; then
    git clone https://github.com/opencollab/arpack-ng
  fi
  cd arpack-ng
  git checkout 3.5.0
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  CC=gcc-7 FC=gfortran-7 cmake -DMPI=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$ALPREFIX ..
  nice make -j8
  make install
  cd ../..
fi

# arpackpp
if [ "$WITH_ARPACKPP" = 1 ]; then
  if [ ! -d arpackpp ]; then
    git clone https://github.com/m-reuter/arpackpp
  fi
  cd arpackpp
  git checkout 88085d99c7cd64f71830dde3855d73673a5e872b
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=$ALPREFIX ..
  make install
  cd ../..
fi

# Eigen
if [ "$WITH_EIGEN" = 1 ]; then
  if [ ! -d eigen-eigen-5a0156e40feb ]; then
    curl -L http://bitbucket.org/eigen/eigen/get/3.3.4.tar.bz2 | tar xvfj -
  fi
  cd eigen-eigen-5a0156e40feb
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=$ALPREFIX ..
  nice make -j8
  make install
  cd ../..
fi

# SPDLog
if [ "$WITH_SPDLOG" = 1 ]; then
  if [ ! -d spdlog ]; then
    git clone https://github.com/gabime/spdlog.git
  fi
  cd spdlog
  git checkout 4fba14c79f356ae48d6141c561bf9fd7ba33fabd
  if [ ! -d build ]; then
    mkdir build
  else
    rm -rf build/*
  fi
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=$ALPREFIX ..
  make install -j8
  cd ../..
fi
