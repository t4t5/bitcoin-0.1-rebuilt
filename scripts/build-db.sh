#!/bin/sh
# Build Berkeley DB 4.7.25 as bitcoin 0.1.0's readme says: from MSYS,
#   cd \DB\build_unix && sh ../dist/configure --enable-mingw --enable-cxx && make
# Runs inside the container. Extra args go to make.
set -eu
cd /wine/drive_c/DB
[ -f dist/configure ] || bsdtar -xzf /downloads/db-4.7.25.tar.gz --no-same-owner --strip-components=1 -C .
# configure's sequence check runs a program that snprintf()s LLONG_MAX with
# "%lld". Wine's msvcrt formats it, Windows XP's msvcrt doesn't know "ll", so
# on Satoshi's machine the check failed and db_seq_t became a 32-bit int (the
# original exe's __env_struct_sig has sizeof(struct __db_seq_record) == 0x14).
# Make the program fail as it did on XP. Only the run result changes: INT64_FMT
# etc. are still set before it, as on XP.
sed -i 's/if (strcmp(buf, "9223372036854775807"))/if (1) \/* XP msvcrt: no %lld *\//' dist/configure
cd /wine/drive_c
wine msys/bin/sh.exe --login -c "cd /c/DB/build_unix && { [ -f Makefile ] || sh ../dist/configure --enable-mingw --enable-cxx; } && make $*"
