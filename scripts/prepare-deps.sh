#!/bin/sh
# Unpack Boost headers ($BOOST, a package in downloads/) into C:\boost and OpenSSL 0.9.8h into C:\OpenSSL,
# and make the libeay32 import library from out/libeay32.def (deps/libeay32.def,
# copied there by build.sh). Runs inside the container.
# C:\boost\.package records which Boost is unpacked; a different $BOOST
# replaces it.
set -eu
c=/wine/drive_c
boost=${BOOST:?set BOOST to a Boost package in downloads/}
if [ "$(cat $c/boost/.package 2>/dev/null)" != "$boost" ]; then
  find $c/boost -mindepth 1 -delete
  bsdtar -xjf "/downloads/$boost" --no-same-owner --strip-components=1 -C $c/boost
  echo "$boost" > $c/boost/.package
fi
[ -f $c/OpenSSL/Configure ] || bsdtar -xzf /downloads/openssl-0.9.8h.tar.gz --no-same-owner --strip-components=1 -C $c/OpenSSL
cd $c/OpenSSL/out
[ -f libeay32.a ] || wine dlltool --dllname libeay32.dll --def libeay32.def --output-lib libeay32.a
