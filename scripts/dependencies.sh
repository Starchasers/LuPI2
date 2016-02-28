#!/bin/bash
#TOOL=arm-musl-linuxeabihf
TOOL=x86_64-linux-musl
OPENSSL_TARGET=linux-generic64
OUT=$TOOL
# TODO: more targets / host target

if [ $# -lt 1 ]
then
  echo "Usage : $0 [all|arm32|x86_64|i486|x86_64-win|i686-win] <libevent|libressl|lua>"
  exit
fi

case "$1" in
  all )
    TARGETS=(arm32 i486 x86_64 x86_64-win i686-win)
    for i in ${TARGETS[@]}; do
      ./$0 $i $2
    done
    ;;
  arm32 )
    TOOL=arm-linux-musleabihf
    OUT=$TOOL
    ;;
  i486 )
    TOOL=i486-linux-musl
    OUT=$TOOL
    ;;
  x86_64 )
    TOOL=x86_64-linux-musl
    OUT=$TOOL
    ;;
  x86_64-win )
    TOOL=x86_64-w64-mingw32
    OUT=$TOOL
    ;;
  i686-win )
    TOOL=i686-w64-mingw32
    OUT=$TOOL
    ;;
  *) echo "Invalid target!" ; exit 1
    ;;
esac

mkdir -p dependencies
mkdir -p dependencies/include
mkdir -p dependencies/include-$OUT

rm -rf dependencies/lib-$OUT
mkdir -p dependencies/lib-$OUT

cd dependencies

#################
# LibreSSL

if [ $2 = "libressl" ] || [ $# -lt 2 ]; then

  git clone https://github.com/libressl-portable/portable.git libressl
  cd libressl
  ./autogen.sh
  ./configure --host=$TOOL
  make clean
  make -j8

  mkdir -p ../include/openssl
  mkdir -p ../include-$OUT/openssl
  cp -fv crypto/.libs/libcrypto.a ../lib-$OUT
  cp -rfv ssl/.libs/libssl.a ../lib-$OUT
  cp -rfv include/openssl/* ../include-$OUT/openssl

  cd ..

fi

#################
# LibEvent

if [ $2 = "libevent" ] || [ $# -lt 2 ]; then

  if [ ! -f "libevent-2.0.22-stable.tar.gz" ]; then
      wget "https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz"
      tar xzvf "libevent-2.0.22-stable.tar.gz"
  fi

  cd libevent-2.0.22-stable

  ./autogen.sh
  ./configure --host=$TOOL
  make clean
  make -j8

  mkdir -p ../include/event2
  mkdir -p ../include-$OUT/event2
  cp -rfv include/event2/* ../include-$OUT/event2
  cp -rv .libs/libevent.a ../lib-$OUT
  cp -fv .libs/libevent_core.a ../lib-$OUT
  cp -fv .libs/libevent_extra.a ../lib-$OUT
  cp -fv .libs/libevent_pthreads.a ../lib-$OUT

  cd ..

fi

#################
# Lua

if [ $2 = "lua" ] || [ $# -lt 2 ]; then

  if [ ! -f "lua-5.3.2.tar.gz" ]; then
      wget "http://www.lua.org/ftp/lua-5.3.2.tar.gz"
      tar xzvf "lua-5.3.2.tar.gz"
  fi

  cd lua-5.3.2

  make clean
  make generic MYCFLAGS=-DLUA_COMPAT_MODULE CC=$TOOL-gcc RANLIB=$TOOL-ranlib #AR=$TOOL-ar

  cp src/liblua.a ../lib-$OUT
  cp src/*.h ../include-$OUT

fi
