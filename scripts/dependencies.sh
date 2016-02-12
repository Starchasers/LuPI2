#!/bin/bash
#TOOL=arm-musl-linuxeabihf
TOOL=x86_64-unknown-linux-gnu
OPENSSL_TARGET=linux-generic32
OUT=$TOOL
# TODO: more targets / host target / musl target from host

if [ $# -lt 1 ]
then
  echo "Usage : $0 [arm32-musl|x86_64|x86_64-musl]"
  exit
fi

case "$1" in
  arm32-musl )
    TOOL=arm-linux-musleabihf
    OUT=$TOOL
    OPENSSL_TARGET=linux-generic32
    ;;
  x86_64 )
    TOOL=x86_64-unknown-linux-gnu
    OUT=$TOOL
    OPENSSL_TARGET=linux-generic64
    ;;
  musl )
    TOOL=x86_64-unknown-linux-gnu
    OUT=musl
    OPENSSL_TARGET=linux-generic64
    ;;
  *) echo "Invalid target!" ; exit 1
    ;;
esac

mkdir -p dependencies

rm -rf dependencies/lib-$OUT
mkdir -p dependencies/lib-$OUT

cd dependencies
git clone git://git.openssl.org/openssl.git
cd openssl

#./Configure 
cd ..
rm -rf openssl-build
mkdir openssl-build
cd openssl-build
../openssl/Configure $OPENSSL_TARGET --unified no-asm -DOPENSSL_NO_HEARTBEATS --openssldir=$(cd ../lib-$OUT; pwd) no-shared
make libcrypto.a -j8 CC=$TOOL-gcc RANLIB=$TOOL-ranlib LD=$TOOL-ld MAKEDEPPROG=$TOOL-gcc PROCESSOR=ARM
make libssl.a -j8 CC=$TOOL-gcc RANLIB=$TOOL-ranlib LD=$TOOL-ld MAKEDEPPROG=$TOOL-gcc PROCESSOR=ARM

cp libcrypto.a ../lib-$OUT
cp libssl.a ../lib-$OUT
