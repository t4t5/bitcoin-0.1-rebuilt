#!/usr/bin/perl
# Add the Windows attributes that Wine can't set to every entry of a RAR 2.9
# archive, in place: NTFS Compressed (0x800) on everything, and Archive (0x20)
# on folders, which Windows XP sets and Wine doesn't. Then recompute each
# header's CRC, the low 16 bits of the CRC-32 of the rest of the header.
# Plain Perl, since the image's perl-base has no CRC or zlib module.
# Usage: rar-attributes.pl archive.rar
use strict;
use warnings;

my $path = shift or die "usage: $0 archive.rar\n";
open my $fh, '+<:raw', $path or die "$path: $!\n";
my $d = do { local $/; <$fh> };

my @table = map {
  my $c = $_;
  $c = $c & 1 ? 0xEDB88320 ^ ($c >> 1) : $c >> 1 for 1 .. 8;
  $c
} 0 .. 255;
sub crc32 {
  my $c = 0xFFFFFFFF;
  $c = $table[($c ^ $_) & 0xFF] ^ ($c >> 8) for unpack 'C*', shift;
  return $c ^ 0xFFFFFFFF;
}

# After the 7-byte marker, each block is a header (CRC, type, flags, header
# size), then for file entries (type 0x74) and blocks with flag 0x8000 a data
# area whose size is the header's next 4 bytes. A file header has the
# attributes at offset 28.
my $p = 7;
while ($p < length $d) {
  my ($type, $flags, $size) = unpack 'x2 C v v', substr($d, $p, 7);
  my $data = $type == 0x74 || $flags & 0x8000 ? unpack 'V', substr($d, $p + 7, 4) : 0;
  if ($type == 0x74) {
    my $attr = unpack('V', substr($d, $p + 28, 4)) | 0x800;
    $attr |= 0x20 if $attr & 0x10;
    substr($d, $p + 28, 4) = pack 'V', $attr;
    substr($d, $p, 2) = pack 'v', crc32(substr($d, $p + 2, $size - 2)) & 0xFFFF;
  }
  $p += $size + $data;
}
seek $fh, 0, 0 or die "$path: $!\n";
print $fh $d or die "$path: $!\n";
close $fh or die "$path: $!\n";
