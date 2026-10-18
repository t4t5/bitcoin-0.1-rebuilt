# Bitcoin 0.1.0, rebuilt byte for byte

This repository rebuilds `bitcoin.exe` from the source in Bitcoin's first release archive and produces a file identical to the one Satoshi Nakamoto shipped in January 2009:

```
fbcac071d92e26d82ec917214e334bd43850c0691f113bab1d4741c9bdd30d2d  bitcoin.exe  (6,440,960 bytes)
```

## Why it's interesting

- **It proves the binary matches the source.** The exe people downloaded in 2009 was built from exactly the source published with it. Nothing else was compiled in, and no byte of the exe is left unexplained.
- **Bitcoin 0.1 was never meant to be reproducible.** It was built once, on Satoshi's own Windows XP machine, with whatever MinGW toolchain was installed there. Matching it meant reconstructing that toolchain from public 2006–2008 packages, down to the binutils snapshot and the line endings of a wxWidgets manifest file.
- **The exe is a record of Satoshi's machine.** Getting every byte right pins down which compiler, libraries, shell and build settings Satoshi used, in what order things were built, and when. See [Satoshi's build machine](#satoshis-build-machine).

## Rebuild it

You need an x86-64 Linux host (the build runs 32-bit Wine, so not ARM), Docker, `curl` and about 2 GB of disk. Then run:

```
./build.sh
```

The first build takes about 6 minutes on a 12-core machine and ends with:

```
[build] MATCH: build/bitcoin/bitcoin.exe has SHA-256 fbcac071d92e26d82ec917214e334bd43850c0691f113bab1d4741c9bdd30d2d
```

If a package has disappeared from its upstream URL, add another URL to its line in `downloads/MANIFEST`, or set `DOWNLOAD_MIRROR` to a directory that has the same file names.

## Satoshi's build machine

Everything here is read from the original exe and confirmed by the rebuild matching it. In order:

1. Around 28 November 2008, on Windows XP, Satoshi built wxWidgets 2.8.9 and Berkeley DB 4.7.25 with MinGW gcc 3.4.5 and a 2006–2007 binutils.
2. Some time after that, Satoshi upgraded binutils to the 2.18.50-20080109 snapshot.
3. On 10 January 2009, Satoshi built bitcoin with its own makefile, running `mingw32-make` from a plain `cmd` window rather than MSYS. The exe was finished at 23:16 UTC.

| Component | What Satoshi used | How we know |
|---|---|---|
| OS | Windows XP | Berkeley DB's configure failed a `%lld` check that XP's msvcrt can't pass |
| Compiler | MinGW gcc 3.4.5 | libgcc's source path is in the exe |
| MinGW runtime | mingw-runtime 3.13 | The shipped `mingwm10.dll` is byte-identical to that release's |
| w32api | 3.10 or 3.11 | The import hints match these two exactly |
| binutils, for the dependencies | 2.17.50 or a little older | wxWidgets' and Berkeley DB's code has an instruction encoding and padding that 2.18.50 doesn't produce |
| binutils, for bitcoin | 2.18.50-20080109 | Bitcoin's own objects, import thunks and section flags have the layout only 2.18.50 produces |
| wxWidgets | 2.8.9 from the Windows installer; debug, ANSI, static | Version-specific strings, and the embedded manifest has CRLF line endings, which only the installer ships |
| Berkeley DB | 4.7.25 | Its version string is in the exe |
| OpenSSL | 0.9.8h, as `libeay32.dll` | The shipped DLL |
| Boost | 1.34.1, headers only | Later versions add functions or change their order |
| Build settings | The makefile's default debug build, then stripped | Debug strings, and no symbol table although the makefile doesn't strip |
| Shell | `cmd`, not MSYS | Include paths like `/wxWidgets/include/...` are verbatim; MSYS would have rewritten them |
| Build times | wxWidgets compiled 28 Nov 2008 08:05:59 local; resources 10 Jan 2009 23:08:02 UTC; stripped 23:16:00 UTC | A `__DATE__`/`__TIME__` string, the resource timestamps and the PE header timestamp |

## Caveats

- **This is the 0.1.1-era binary, not the launch-day one.** The archive named `bitcoin-0.1.0` is really the 10 January 2009 update (`serialize.h` has `VERSION = 101`), and its exe was built that day. No verified copy of the 8 January package is known to survive.
- **Three timestamps are inputs.** The build sets the clock for the three steps that embed it to the times recorded in the original exe. Without them the build differs in exactly those 335 bytes.
- **The two DLLs aren't rebuilt.** `libeay32.dll`'s import library is generated from the shipped DLL's export table, and `mingwm10.dll` comes from mingw-runtime 3.13.
- **It runs under Wine, not Windows XP.** A few small workarounds in `scripts/` make Wine behave like XP where it matters.

## The original archives

`original/archives/` holds the 0.1.0 release archives from the [Satoshi Nakamoto Institute](https://satoshi.nakamotoinstitute.org/code/). Their MD5 and SHA-1 match the ones SNI publishes, and the build checks them before it starts.
