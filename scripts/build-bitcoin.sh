#!/bin/sh
# Build bitcoin 0.1.0 with its own makefile, from cmd (not MSYS): the original
# exe contains assert paths like "/wxWidgets/include/wx/string.h", which MSYS
# would have rewritten to C:/msys/... before they reached gcc.
# Runs inside the container. Usage: build-bitcoin.sh [mingw32-make args...]
# $WINDRES_TIME and $STRIP_TIME (seconds since the epoch) are the wall-clock
# times for windres, which stamps every resource directory with it, and for
# strip, which rewrites the PE header's TimeDateStamp (the link time is lost).
set -eu
c=/wine/drive_c
# The source is the release archive's src/ (checked against original/MANIFEST
# by build.sh), including its empty obj/ dir
rm -rf $c/bitcoin/*
bsdtar -xzf /work/original/archives/bitcoin-0.1.0.tgz --no-same-owner --strip-components=2 -C $c/bitcoin bitcoin/src
# Satoshi's machine had a setup.h under vc_lib/mswd, which a fresh one lacks
# (the makefile points there; wx itself was built with makefile.gcc, which puts
# it under gcc_lib/mswd).
mkdir -p $c/wxWidgets/lib/vc_lib/mswd/wx
cp $c/wxWidgets/lib/gcc_lib/mswd/wx/setup.h $c/wxWidgets/lib/vc_lib/mswd/wx/setup.h
# Wine resolves a drive-less "/boost" as a Unix path, where real Windows would
# use the current drive. Link the Unix paths to the C: dirs so gcc still gets
# the literal "/boost" etc. that ends up in the exe's assert strings.
for d in boost wxWidgets DB OpenSSL; do ln -sfn $c/$d /$d; done
# Runs a command with the wall clock fixed at $1 (or unchanged if it's empty).
# The wineserver is started first without the shim: faking its clock hangs it.
wineserver -p 2>/dev/null || true  # fails if one is already running, which is fine
at() {
  t=$1; shift
  [ -n "$t" ] || { "$@"; return; }
  rc=0
  LD_PRELOAD=/usr/local/lib/i386/fixedtime.so FIXED_TIME=$t "$@" 2>/tmp/at.err || rc=$?
  grep -v 'wrong ELF class' /tmp/at.err >&2 || true
  return $rc
}
# Start from C:\bitcoin, not Wine's Z: view of the same directory, so that
# "/boost" etc. resolve against the C: root.
at "${WINDRES_TIME:-}" wine cmd /c "cd /d C:\\bitcoin && mingw32-make obj/ui_res.o"
wine cmd /c "cd /d C:\\bitcoin && mingw32-make $*"
cd $c/bitcoin
cp bitcoin.exe bitcoin-unstripped.exe
at "${STRIP_TIME:-}" wine strip bitcoin.exe
