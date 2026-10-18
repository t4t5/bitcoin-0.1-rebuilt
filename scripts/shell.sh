#!/bin/sh
# Start the build container. Its C:\MinGW, C:\msys, C:\wxWidgets, C:\DB,
# C:\OpenSSL, C:\boost and C:\bitcoin live under build/ on the host,
# so they persist between runs and can be inspected. Those are the paths the
# original makefile expects ("/wxWidgets" etc. resolve against the C: root).
# The btc2009-wine image comes from docker/ (build.sh builds it, or
# run docker build -t btc2009-wine docker).
# The container runs as root. Under rootless Docker that's the host user; under
# rootful Docker the files it writes would belong to the host's root, so when the
# command ends they're handed to the owner of the checkout.
# Usage: scripts/shell.sh [command...]
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
c="$root/build"
mounts="" dirs=""
for d in MinGW msys wxWidgets DB OpenSSL boost bitcoin; do
  mkdir -p "$c/$d"
  mounts="$mounts -v $c/$d:/wine/drive_c/$d"
  dirs="$dirs /wine/drive_c/$d"
done
exec docker run --rm --network none -i $( [ -t 0 ] && echo -t ) \
  -v "$root/downloads:/downloads:ro" \
  -v "$root:/work:ro" \
  $mounts \
  -e WINEPATH='C:\MinGW\bin' \
  -e BUILD_DIRS="$dirs" \
  btc2009-wine sh -c '
    rc=0; "$@" || rc=$?
    owner=$(stat -c %u:%g /work)
    [ "$owner" = 0:0 ] || chown -R "$owner" $BUILD_DIRS
    exit $rc' sh "${@:-bash}"
