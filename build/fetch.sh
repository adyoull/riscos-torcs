#!/bin/bash
# Fetch the source tarballs (if missing) into $DL, check them against
# build/SHA256SUMS, and unpack TORCS into $TORCS_SRC with patches/torcs
# applied (as git commits, so the series can be edited with git and
# exported again: see BUILDING.md).
#   build/fetch.sh
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$DL"
UB=http://archive.ubuntu.com/ubuntu/pool
declare -A URL=(
  [torcs_1.3.7+dfsg.orig.tar.xz]=$UB/universe/t/torcs
  [plib_1.8.5.orig.tar.gz]=$UB/universe/p/plib
  [freealut_1.1.0.orig.tar.gz]=$UB/main/f/freealut
  [libpng1.6_1.6.37.orig.tar.gz]=$UB/main/libp/libpng1.6
  [libogg_1.3.5.orig.tar.gz]=$UB/main/libo/libogg
  [libvorbis_1.3.7.orig.tar.gz]=$UB/main/libv/libvorbis
)
for f in "${!URL[@]}"; do
  [ -f "$DL/$f" ] || { echo "fetching $f"; curl -sSfL -o "$DL/$f" "${URL[$f]}/$f"; }
done
(cd "$DL" && grep -E "torcs_1.3.7\+dfsg.orig|plib_1.8.5.orig|freealut|libpng|libogg|libvorbis" \
   "$RT_DIR/build/SHA256SUMS" | sha256sum -c --quiet -)

if [ ! -d "$TORCS_SRC" ]; then
  echo "unpacking TORCS"
  mkdir -p "$WORK/unpack"
  tar xJf "$DL/torcs_1.3.7+dfsg.orig.tar.xz" -C "$WORK/unpack"
  mv "$WORK/unpack/torcs-1.3.7+dfsg" "$TORCS_SRC"; rmdir "$WORK/unpack"
  cd "$TORCS_SRC"
  git init -q
  # The game data (737 MB) isn't part of the patched tree.
  printf 'data/\n*.o\n*.a\n*.so\n.depend\nexport/\nsrc/libs/txml/gennmtab/gennmtab\nsrc/linux/riscos_modtab.cpp\nsrc/linux/torcs\nsrc/linux/torcs.map\n' > .git/info/exclude
  git add -A
  git -c user.name=upstream -c user.email=upstream@invalid commit -qm "TORCS 1.3.7+dfsg (Debian)"
  git tag upstream
  while read -r p; do
    [ -n "$p" ] || continue
    git -c user.name="Andrew Youll" -c user.email=andrewyoull86@gmail.com am -q --keep-cr --committer-date-is-author-date "$RT_DIR/patches/torcs/$p"
    echo "  applied $p"
  done < "$RT_DIR/patches/torcs/series"
fi
echo "sources ready in $WORK"
