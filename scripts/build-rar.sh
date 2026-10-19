#!/bin/sh
# Pack the rebuilt bitcoin.exe and the rest of the release into
# bitcoin-0.1.0.rar the way Satoshi did, with WinRAR 3.51's Rar.exe. build.sh
# checks the result against the release archive's hashes in original/MANIFEST.
# What the original archive's headers and data show (see README.md):
# - WinRAR 3.40 to 3.51: earlier and later 3.x releases compress differently
# - Best compression (-m5), a 4 MB dictionary, solid
# - files sorted by extension, which is the order Rar.exe uses when there's no
#   RarFiles.lst next to it, so only Rar.exe is unpacked from the installer
# - the file and folder times below, in local time (the container's is UTC)
# - the NTFS Compressed attribute on every entry, which Wine can't set, so
#   rar-attributes.pl adds it afterwards
# Runs inside the container, after build-bitcoin.sh. Usage: build-rar.sh
set -eu
export TZ=UTC
c=/wine/drive_c r=/wine/drive_c/rar
rm -rf $r/*
mkdir -p $r/bin $r/files
unar -q -D -o $r/bin /downloads/wrar351.exe Rar.exe
# Everything but the exe comes from the release archive (checked against
# original/MANIFEST by build.sh)
bsdtar -xzf /work/original/archives/bitcoin-0.1.0.tgz --no-same-owner --strip-components=1 -C $r/files
cp $c/bitcoin/bitcoin.exe $r/files/bitcoin.exe
cd $r/files
# The files' times are whole minutes, so Satoshi probably set them by hand.
# Folders last, since adding files to a folder changes its time.
find . -type f -exec touch -d '2009-01-07 01:00:00' {} +
touch -d '2009-01-10 01:01:00' bitcoin.exe src/irc.cpp src/serialize.h
touch -d '2009-01-07 15:36:27.46875' src/obj
touch -d '2009-01-07 15:37:33.671875' src/rc
touch -d '2009-01-10 23:15:06.703125' src
wine $r/bin/Rar.exe a -m5 -md4096 -s -r -y 'C:\rar\bitcoin-0.1.0.rar' '*'
perl /work/scripts/rar-attributes.pl $r/bitcoin-0.1.0.rar
