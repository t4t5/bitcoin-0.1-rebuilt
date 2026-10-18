#!/bin/sh
# Download the files toolchain.txt needs into downloads/ and check each
# against its SHA-256 in downloads/MANIFEST. Files already there are only
# checked, and one that doesn't match stops the run.
# A download tries the manifest line's URLs in order, then <mirror>/<file> if
# $DOWNLOAD_MIRROR is set (old MinGW packages do disappear from SourceForge),
# until one has the right SHA-256.
# Usage: scripts/fetch.sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
spec=toolchain.txt
dl="$root/downloads" manifest="$root/downloads/MANIFEST"

# Package lines, then the packages named by settings, then the ones every
# build uses (scripts/build-db.sh, scripts/prepare-deps.sh)
files=$(
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e '/=/d' "$root/$spec"
  sed -n 's/^\(boost\|msys\|wx\|upgrade\)=//p' "$root/$spec"
  echo db-4.7.25.tar.gz
  echo openssl-0.9.8h.tar.gz
)

sha() { sha256sum "$1" | cut -d' ' -f1; }
mkdir -p "$dl"
for f in $files; do
  line=$(awk -v f="$f" '$2 == f' "$manifest")
  [ -n "$line" ] || { echo "$f: not in downloads/MANIFEST" >&2; exit 1; }
  want=$(echo "$line" | awk '{print $1}')
  if [ -f "$dl/$f" ]; then
    got=$(sha "$dl/$f")
    [ "$got" = "$want" ] || { echo "$f: SHA-256 is $got, expected $want" >&2; exit 1; }
    continue
  fi
  for url in $(echo "$line" | awk '{for (i = 3; i <= NF; i++) print $i}') ${DOWNLOAD_MIRROR:+"$DOWNLOAD_MIRROR/$f"}; do
    echo "fetch $f from $url"
    if curl -fL --retry 3 -sS -o "$dl/$f.part" "$url"; then
      got=$(sha "$dl/$f.part")
      [ "$got" = "$want" ] && break
      echo "$f: SHA-256 is $got, expected $want" >&2
    fi
    rm -f "$dl/$f.part"
  done
  [ -f "$dl/$f.part" ] || { echo "$f: download failed" >&2; exit 1; }
  mv "$dl/$f.part" "$dl/$f"
done
