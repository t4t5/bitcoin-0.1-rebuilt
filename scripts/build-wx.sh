#!/bin/sh
# Build wxWidgets 2.8.9 the stock way (build\msw\makefile.gcc), debug, static,
# ANSI. Runs inside the container. Extra args go to mingw32-make.
# $WX picks the source package (a wxMSW-2.8.9 package in downloads/). The Setup.exe installer
# has CRLF text files, which the original exe shows in its RT_MANIFEST resource
# (wx/msw/wx.manifest, embedded verbatim by windres); the .tar.gz and .zip are LF.
# $WINCMN_TIME (seconds since the epoch, UTC) is the wall-clock time for
# compiling src/common/wincmn.cpp, the one wx source whose __DATE__/__TIME__
# reaches the exe ("compiled at ...").
set -eu
wx=${WX:?set WX to a wxMSW-2.8.9 package in downloads/}
cd /wine/drive_c/wxWidgets
if [ ! -f include/wx/wx.h ]; then
  case $wx in
    *.exe) rm -rf /tmp/wxsetup && innoextract -s -d /tmp/wxsetup "/downloads/$wx" && cp -r /tmp/wxsetup/app/. . ;;
    *) bsdtar -xzf "/downloads/$wx" --no-same-owner --strip-components=1 -C . ;;
  esac
fi
cd build/msw
if [ -n "${WINCMN_TIME:-}" ] && [ ! -f gcc_mswd/corelib_wincmn.o ] && [ "$*" != setup_h ]; then
  # the wineserver is started first without the shim: faking its clock hangs it
  wineserver -p 2>/dev/null || true  # fails if one is already running, which is fine
  mkdir -p gcc_mswd  # the full build creates it; this target alone does not
  rc=0
  LD_PRELOAD=/usr/local/lib/i386/fixedtime.so FIXED_TIME=$WINCMN_TIME \
    wine mingw32-make -f makefile.gcc BUILD=debug 'gcc_mswd\corelib_wincmn.o' 2>/tmp/at.err || rc=$?
  grep -v 'wrong ELF class' /tmp/at.err >&2 || true
  [ $rc = 0 ]
fi
wine mingw32-make -f makefile.gcc BUILD=debug "$@"
