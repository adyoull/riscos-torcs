#!/bin/bash
# Make the RISC OS test zip: dist/TORCS-<version>.zip with !TORCS (app/,
# the game data installed by TORCS's own "make install datainstall", the
# RISC OS default settings and the program as an Absolute file).
#   build/package.sh VERSION      (after build/build-torcs.sh)
# TRACKS: the tracks to include (category/name ...), default a set of 9;
# TRACKS=all for every track (about 435 MB). TRACKS_PACK=NAME also makes
# dist/NAME.zip with all the other tracks (the tracks pack).
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

# The version: the program compares it with the one in the settings
# directory to tell a new version (riscosplatform.cpp).
echo "$VERSION" > "$APP/Version"

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

# --- the tracks pack: every track not in the application, in a zip whose
# !TORCS directory is copied over the installed one (the tracks belong to
# the game data, not to a port release, hence the TORCS version in its name)
if [ "$TRACKS" != all ] && [ -n "${TRACKS_PACK:-}" ]; then
  PK="$STAGE_PKG/pack/TORCS-tracks"; mkdir -p "$PK/!TORCS/tracks"
  for cd in "$DATA"/tracks/*/; do
    cat=$(basename "$cd")
    for td in "$cd"*/; do
      t=$cat/$(basename "$td")
      [ -d "$APP/tracks/$t" ] && continue
      mkdir -p "$PK/!TORCS/tracks/$cat"; cp -r "$td" "$PK/!TORCS/tracks/$t"
    done
  done
  cp "$RT_DIR/riscos/TracksPack-ReadMe,fff" "$PK/ReadMe,fff"
  rm -f "$OUT/$TRACKS_PACK.zip"
  python3 "$RISCOS_DEVKIT/bin/mkrozip.py" "$OUT/$TRACKS_PACK.zip" "$PK"
  ls -d "$PK/!TORCS/tracks"/*/* | sed 's|.*/tracks/||' | tr '\n' ' '; echo
  ls -l "$OUT/$TRACKS_PACK.zip"; md5sum "$OUT/$TRACKS_PACK.zip"
fi
rm -rf "$STAGE_PKG"
ls -l "$OUT/TORCS-$VERSION.zip"; md5sum "$OUT/TORCS-$VERSION.zip"
