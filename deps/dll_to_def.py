# /// script
# dependencies = ["pefile==2024.8.26"]
# ///
"""Write a .def for a DLL from its export table, keeping export order and ordinals,
so dlltool can regenerate an import library equivalent to the original.

Usage: uv run deps/dll_to_def.py <file.dll> > out.def
"""

import sys

import pefile

pe = pefile.PE(sys.argv[1])
print(f"LIBRARY {pe.DIRECTORY_ENTRY_EXPORT.name.decode()}")
print("EXPORTS")
for s in pe.DIRECTORY_ENTRY_EXPORT.symbols:
    print(f"  {s.name.decode()} @{s.ordinal}")
