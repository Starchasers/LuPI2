#!/bin/bash
#TOOL=arm-musl-linuxeabihf
TOOL=x86_64-linux-musl
OPENSSL_TARGET=linux-generic64
OUT=$TOOL
# TODO: more targets / host target

if [ $# -lt 1 ]
then
  echo "Usage : $0 [all|arm32|x86_64|i486]"
  exit
fi

case "$1" in
  all )
    TARGETS=(arm32 i486 x86_64)
    for i in ${TARGETS[@]}; do
      ./$0 $i
    done
    ;;
  arm32 )
    TOOL=arm-linux-musleabihf
    OUT=$TOOL
    OPENSSL_TARGET=linux-generic32
    ;;
  i486 )
    TOOL=i486-linux-musl
    OUT=$TOOL
    OPENSSL_TARGET=linux-generic32
    ;;
  x86_64 )
    TOOL=x86_64-linux-musl
    OUT=$TOOL
    OPENSSL_TARGET=linux-generic64
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
git clone https://github.com/libressl-portable/portable.git libressl
cd libressl
./autogen.sh
./configure --host=$TOOL
make clean
make -j8

mkdir -p ../include/openssl
mkdir -p ../include-$OUT/openssl
cp -rfv crypto/.libs/libcrypto.a ../lib-$OUT
cp -rfv ssl/.libs/libssl.a ../lib-$OUT
cp -rfv include/openssl/* ../include-$OUT/openssl
