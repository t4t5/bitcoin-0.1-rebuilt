#!/bin/sh
# Rebuild bitcoin.exe 0.1.0 from the source in its release archive and check
# that it's byte-identical to the released one. See README.md.
# Steps: release archive check, build image, downloads, toolchain, wxWidgets,
# Boost/OpenSSL, Berkeley DB, binutils upgrade, bitcoin. The build goes to
# build/ (the exe is build/bitcoin/bitcoin.exe), logs to logs/. Finished
# dependency builds are reused; delete build/<dir> to redo one. Exits non-zero
# unless the SHA-256 matches.
# Usage: ./build.sh
set -eu
root=$(cd "$(dirname "$0")" && pwd)
b="$root/build"
spec=toolchain.txt
# SHA-256 of the released bitcoin.exe (bitcoin/bitcoin.exe in
# original/archives/bitcoin-0.1.0.tgz)
expected=fbcac071d92e26d82ec917214e334bd43850c0691f113bab1d4741c9bdd30d2d

die() { echo "build.sh: $*" >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || die "needs an x86-64 host (the build runs 32-bit Wine)"
for c in docker curl awk md5sum sha1sum sha256sum; do
  command -v $c > /dev/null || die "needs $c"
done
docker info > /dev/null 2>&1 || die "can't reach the Docker daemon"

# key=value settings in toolchain.txt; an empty default means it must set it
setting() {
  v=$(sed -n "s/^$1=//p" "$root/$spec")
  [ -n "$v" ] || [ $# -gt 1 ] || die "$spec: missing $1="
  echo "${v:-${2:-}}"
}
boost=$(setting boost)
msys=$(setting msys)
wx=$(setting wx)
# A package unpacked over the toolchain after the dependencies are built and
# before bitcoin is (Satoshi upgraded binutils in between, see README.md).
upgrade=$(setting upgrade "")
# Wall-clock times (seconds since the epoch) for the steps that embed them
wincmn_time=$(setting wincmn_time)
windres_time=$(setting windres_time)
strip_time=$(setting strip_time)
jobs=$(nproc)
mkdir -p "$root/logs"
log() { echo "[build] $*"; }
# Run a command in the container, dropping Wine's fixme noise but keeping the
# command's exit status (a plain pipe into grep would lose it, and grep itself
# fails when a step prints nothing).
run() {
  out=$(mktemp) rc=0
  "$root/scripts/shell.sh" "$@" > "$out" 2>&1 || rc=$?
  grep -v ':fixme:' "$out" || true
  rm -f "$out"
  return $rc
}

# The source comes from the release archive, which must match the published
# MD5 and SHA-1 and the SHA-256 in original/MANIFEST
log archive
tgz="$root/original/archives/bitcoin-0.1.0.tgz"
read -r md5 sha1 sha256 _ <<EOF
$(awk '!/^#/ && $4 == "bitcoin-0.1.0.tgz"' "$root/original/MANIFEST")
EOF
[ "$(md5sum < "$tgz" | cut -d' ' -f1)" = "$md5" ] &&
  [ "$(sha1sum < "$tgz" | cut -d' ' -f1)" = "$sha1" ] &&
  [ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$sha256" ] ||
  die "original/archives/bitcoin-0.1.0.tgz doesn't match original/MANIFEST"

log image; docker build -q -t btc2009-wine "$root/docker" > /dev/null
log downloads; "$root/scripts/fetch.sh"

deps_built() {
  [ -f "$b/wxWidgets/lib/gcc_lib/libwxmsw28d_core.a" ] && [ -f "$b/DB/build_unix/libdb_cxx.a" ]
}
if [ ! -f "$b/MinGW/bin/gcc.exe" ] || ! cmp -s "$root/$spec" "$b/toolchain.txt" ||
   { [ -f "$b/MinGW/.upgraded" ] && ! deps_built; }; then
  log toolchain; run sh /work/scripts/setup-toolchain.sh > "$root/logs/toolchain.log"
  cp "$root/$spec" "$b/toolchain.txt"
fi
if [ ! -f "$b/msys/bin/sh.exe" ]; then
  log msys
  run sh -c "cd /tmp && innoextract -s -d m /downloads/$msys && cp -r m/app/. /wine/drive_c/msys/" > "$root/logs/msys.log"
  printf 'C:/MinGW /mingw\n' > "$b/msys/etc/fstab"
fi
if [ ! -f "$b/wxWidgets/lib/gcc_lib/libwxmsw28d_core.a" ]; then
  log wxWidgets
  run env WX="$wx" JOBS=$jobs WINCMN_TIME="$wincmn_time" sh -c 'sh /work/scripts/build-wx.sh setup_h && sh /work/scripts/build-wx.sh -j$JOBS' > "$root/logs/wx.log"
fi
if [ ! -f "$b/OpenSSL/out/libeay32.a" ] || [ "$(cat "$b/boost/.package" 2>/dev/null)" != "$boost" ]; then
  log boost+openssl
  mkdir -p "$b/OpenSSL/out"
  cp "$root/deps/libeay32.def" "$b/OpenSSL/out/libeay32.def"
  run env BOOST="$boost" sh /work/scripts/prepare-deps.sh > "$root/logs/deps.log"
fi
if [ ! -f "$b/DB/build_unix/libdb_cxx.a" ]; then
  log berkeley-db; run sh /work/scripts/build-db.sh -j$jobs > "$root/logs/db.log"
fi
if [ -n "$upgrade" ] && [ ! -f "$b/MinGW/.upgraded" ]; then
  log "upgrade $upgrade"
  run bsdtar -xf "/downloads/$upgrade" --no-same-owner -C /wine/drive_c/MinGW > "$root/logs/upgrade.log"
  echo "$upgrade" > "$b/MinGW/.upgraded"
fi
log bitcoin; run env WINDRES_TIME="$windres_time" STRIP_TIME="$strip_time" sh /work/scripts/build-bitcoin.sh > "$root/logs/bitcoin.log"
got=$(sha256sum "$b/bitcoin/bitcoin.exe" | cut -d' ' -f1)
[ "$got" = "$expected" ] || die "MISMATCH: build/bitcoin/bitcoin.exe has SHA-256 $got, expected $expected"
log "MATCH: build/bitcoin/bitcoin.exe has SHA-256 $got"
