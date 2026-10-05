# Licensing

- **TORCS** 1.3.7 (Debian's `torcs_1.3.7+dfsg` source): GNU GPL 2 or later.
  A few files are under other licences (SOLID 2.0 and `grloadac.cpp`: LGPL 2
  or later; `fg_gm.cpp`: MIT/X), listed in Debian's copyright file.
- **The game data** (cars, tracks, robots' settings, menus): the licences in
  Debian's copyright file, shipped as `Licences.TORCS-data`. Debian's `+dfsg`
  repack removed the data that wasn't free software, which is why some robot
  drivers report "Bad Car category" for cars that aren't there.
- **This port** (the patches, `riscosspec.cpp`, `riscosplatform.cpp`, the
  scripts, the application files): GNU GPL 2 or later, as TORCS (`LICENSE`).
  The plib patch (`patches/plib/10-riscos-platform.patch`, including
  `jsRISCOS.cxx`) is under plib's licence, the GNU LGPL 2 or later.
- **Libraries linked into the program:** plib 1.8.5 (LGPL 2+ with Steve
  Baker's linking exception), freealut 1.1.0 (LGPL 2), libpng 1.6.37,
  libogg 1.3.5 and libvorbis 1.3.7 (BSD-style), and from the riscos-mesa
  devkit Mesa, EGL, GLU, freeglut, SDL 2, OpenAL Soft (LGPL 2), zlib and
  UnixLib. The application carries every licence (`riscos/licences/`).
- **LGPL relinking:** everything is linked statically; this repository has
  the scripts and sources to rebuild and relink with a changed library.
- **GPL corresponding source:** this repository plus the tarballs named in
  `build/SHA256SUMS` (all from archive.ubuntu.com). A release should be
  published next to the source, e.g. as a GitHub release of this repository.
