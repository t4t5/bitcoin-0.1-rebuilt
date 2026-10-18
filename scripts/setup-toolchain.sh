#!/bin/sh
# Unpack the packages toolchain.txt lists (one filename per line, from
# downloads/) into C:\MinGW of the container's Wine prefix. Lines of the form
# key=value are settings for build.sh and are skipped here. Runs inside the
# container.
set -eu
spec=/work/toolchain.txt
dest="$WINEPREFIX/drive_c/MinGW"
# dest is a bind mount, so empty it rather than removing it
find "$dest" -mindepth 1 -delete
mkdir -p "$dest"
sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e '/=/d' "$spec" | while read -r pkg; do
  echo "unpack $pkg"
  bsdtar -xf "/downloads/$pkg" --no-same-owner -C "$dest"
done
