#!/bin/bash
# Make the RISC OS test zip: dist/TORCS-<version>.zip with !TORCS (app/,
# the game data installed by TORCS's own "make install datainstall", the
# RISC OS default settings and the program as an Absolute file).
#   build/package.sh VERSION      (after build/build-torcs.sh)
# TRACKS: the tracks to include (category/name ...), default a small set
# for testing; TRACKS=all for every track (about 435 MB).
set -euo pipefail
. "$(dirname "$0")/env.sh"
VERSION=${1:?usage: package.sh VERSION}
: "${TRACKS:=road/forza road/g-track-2 road/e-track-4 road/e-track-1 road/aalborg oval/a-speedway oval/b-speedway dirt/mixed-2 dirt/dirt-4}"
OUT="$RT_DIR/dist"; STAGE_PKG=$(mktemp -d)
APP="$STAGE_PKG/!TORCS"

# --- the game data, as TORCS installs it ---
INST="$WORK/inst"
rm -rf "$INST"
(cd "$TORCS_SRC" && export TORCS_BASE=$PWD MAKE_DEFAULT=$PWD/Make-default.mk && \
 make RISCOS_STATIC=1 DESTDIR="$INST" install datainstall > "$WORK/install.log" 2>&1) \
  || { tail -20 "$WORK/install.log"; exit 1; }
DATA="$INST/riscos/share/games/torcs"

cp -r "$RT_DIR/app/!TORCS" "$APP"
for d in cars categories config data drivers menu results wheels; do
  [ -d "$DATA/$d" ] && cp -r "$DATA/$d" "$APP/"
done
cp "$DATA/logo-skinner.png" "$DATA/tux.png" "$APP/" 2>/dev/null || true
mkdir -p "$APP/tracks"
if [ "$TRACKS" = all ]; then
  cp -r "$DATA/tracks/." "$APP/tracks/"
else
  for t in $TRACKS; do
    mkdir -p "$APP/tracks/$(dirname "$t")"
    cp -r "$DATA/tracks/$t" "$APP/tracks/$t"
  done
fi
mkdir -p "$APP/results"

# --- RISC OS default settings (riscos/defaults.py says what and why) ---
python3 "$RT_DIR/riscos/defaults.py" "$APP"

# --- licences ---
L="$APP/Licences"; mkdir -p "$L"
cp "$TORCS_SRC/COPYING" "$L/COPYING"
cp "$RT_DIR/riscos/licences/"* "$L/"

# --- the program: an Absolute (AIF) file, so it needs no ELF loader ---
arm-riscos-gnueabihf-strip -o "$STAGE_PKG/torcs.elf" "$TORCS_SRC/src/linux/torcs"
elf2aif -e "$STAGE_PKG/torcs.elf" "$APP/!RunImage,ff8"
rm "$STAGE_PKG/torcs.elf"

if grep -rqa "$WORK" "$APP/!RunImage,ff8"; then echo "build path found in the program" >&2; exit 1; fi
mkdir -p "$OUT"; rm -f "$OUT/TORCS-$VERSION.zip"
python3 "$RISCOS_DEVKIT/bin/mkrozip.py" "$OUT/TORCS-$VERSION.zip" "$APP"
du -sh "$APP"
rm -rf "$STAGE_PKG"
ls -l "$OUT/TORCS-$VERSION.zip"; md5sum "$OUT/TORCS-$VERSION.zip"
