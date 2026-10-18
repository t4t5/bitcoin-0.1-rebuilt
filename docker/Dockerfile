# Wine host for the 2009-era MinGW toolchain. The toolchain itself is not baked
# in: scripts/setup-toolchain.sh unpacks the packages toolchain.txt lists from
# downloads/ into the prefix.
# apt reads a fixed Debian snapshot (snapshot.sources) rather than the live
# mirrors, so a later build of this image gets the same Wine. Snapshot Release
# files expire, hence Check-Valid-Until=false.

# i386 build of fixedtime.c, an LD_PRELOAD shim that fixes the wall clock for
# one Wine process (see the file)
FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587 AS fixedtime
COPY snapshot.sources /etc/apt/sources.list.d/debian.sources
RUN apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends gcc gcc-multilib libc6-dev \
 && rm -rf /var/lib/apt/lists/*
COPY fixedtime.c /src/
RUN gcc -m32 -shared -fPIC -O2 -o /src/fixedtime.so /src/fixedtime.c -ldl

FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587

COPY snapshot.sources /etc/apt/sources.list.d/debian.sources
RUN dpkg --add-architecture i386 \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      wine=8.0~repack-4 wine32:i386=8.0~repack-4 make bzip2 xz-utils ca-certificates libarchive-tools innoextract \
 && rm -rf /var/lib/apt/lists/*

# Runs as root: under rootless Docker that is the host user, so files written to
# the mounted build dirs stay owned by them.
ENV WINEPREFIX=/wine WINEARCH=win32 WINEDEBUG=-all
RUN wineboot --init && wineserver -w

COPY --from=fixedtime /src/fixedtime.so /usr/local/lib/i386/fixedtime.so

WORKDIR /work

