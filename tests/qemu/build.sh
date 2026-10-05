#!/bin/bash
# ARM Linux build of the patched TORCS (static modules, RISC OS start-up
# code) for the QEMU alignment test (run.sh). Same compiler settings that
# matter for RISC OS: ARMv7, VFPv3, -mno-unaligned-access. glibc instead of
# UnixLib, so it tests TORCS's own code (track loader, physics, robots,
# XML), not the RISC OS libraries. GL, GLUT, OpenAL and the image/sound
# libraries are stubs that return 0: the console race (-r) draws nothing.
#   . build/env.sh; QDIR=<build dir> tests/qemu/build.sh
# Needs g++-arm-linux-gnueabihf (Ubuntu) and build/build-deps.sh's staged
# headers.
set -euo pipefail
. "$(dirname "$0")/../../build/env.sh"
: "${QDIR:=$WORK/qemu}"
X=arm-linux-gnueabihf
QF="-O2 -g -march=armv7-a -mfpu=vfpv3 -mfloat-abi=hard -mno-unaligned-access -fno-delete-null-pointer-checks"
mkdir -p "$QDIR"
# plib for ARM Linux (UL_LINUX), from build-deps.sh's patched sources
P=$WORK/deps/plib-1.8.5/src
if [ ! -f "$QDIR/plib/libplibsm.a" ]; then
  mkdir -p "$QDIR/plib"
  for d in util:ul sg:sg ssg:ssg ssgAux:ssgaux js:js sl:sl; do
    dir=${d%%:*}; lib=${d#*:}; rm -rf "$QDIR/plib/o-$lib"; mkdir -p "$QDIR/plib/o-$lib"
    for s in $(cd $P/$dir && ls *.cxx); do
      case "$dir:$s" in js:js*.cxx) [ "$s" = js.cxx ] || [ "$s" = jsLinux.cxx ] || continue;; sl:sm*) continue;; esac
      $X-g++ $QF -I$P/util -I$P/sg -I$P/ssg -I$P/js -I$P/sl -I$RISCOS_DEVKIT/include -c $P/$dir/$s -o "$QDIR/plib/o-$lib/${s%.cxx}.o"
    done
    $X-ar rcs "$QDIR/plib/libplib$lib.a" "$QDIR/plib/o-$lib/"*.o
  done
  $X-g++ $QF -I$P/util -I$P/sl -c $P/sl/smMixer.cxx -o "$QDIR/plib/smMixer.o"
  $X-ar rcs "$QDIR/plib/libplibsm.a" "$QDIR/plib/smMixer.o"
fi
T=$QDIR/torcs
if [ ! -d "$T" ]; then
  mkdir -p "$T"; (cd "$TORCS_SRC" && git ls-files | tar cf - -T -) | tar xf - -C "$T"
fi
cd "$T"
sed -e "s/^CC = .*/CC = $X-gcc/; s/^CXX = .*/CXX = $X-g++/; s/^LD = .*/LD = $X-ld/; s/^AR = .*/AR = $X-ar/" \
    -e "s/^OBJCOPY = .*/OBJCOPY = $X-objcopy/; s/^RANLIB = .*/RANLIB = $X-ranlib/" \
    -e "s/^CPP = .*/CPP = $X-gcc -E \${RISCOS_INC} -M -D__DEPEND__/" \
    -e 's/^CFLAGSD = .*/CFLAGSD = -D_GNU_SOURCE -DHAVE_CONFIG_H -DTORCS_STATIC_MODULES -DTORCS_SOFTWARE_GL/' \
    Make-config.riscos > Make-config
cp config.h.riscos config.h
export TORCS_BASE=$PWD MAKE_DEFAULT=$PWD/Make-default.mk RISCOS_CFLAGS="$QF" RISCOS_MAP=
mkdir -p export/lib export/include
make RISCOS_STATIC=1 > make-qemu.log 2>&1 || { tail -30 make-qemu.log; exit 1; }
MODS=$(cd export && find modules drivers -name '*.so' | sort)
TAB=src/linux/riscos_modtab.cpp
{ echo '#include "riscosspec.h"'; echo 'extern "C" {'
  for m in $MODS; do echo "int $(basename "$m" .so)(tModInfo *);"; done
  echo '}'; echo 'const tRiscosModule RiscosModules[] = {'
  for m in $MODS; do n=$(basename "$m" .so); echo "  { \"$(dirname "$m")\", \"$n\", $n, NULL },"; done
  echo '  { NULL, NULL, NULL, NULL } };'; } > $TAB
$X-g++ $QF -Iexport/include -I. -I$STAGE/include -I$RISCOS_DEVKIT/include -c $TAB -o src/linux/riscos_modtab.o
LINK() {
  $X-g++ -no-pie -o src/linux/torcs-arm src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o \
    src/linux/riscos_modtab.o $(for m in $MODS; do echo "export/$m"; done) "$@" -Lexport/lib -L"$QDIR/plib" \
    -Wl,--start-group -lracescreens -lraceengine -lclient -lconfscreens -lrobottools -llearning \
    -lmusicplayer -ltgfclient -ltgf -ltxml -lsolid -Wl,--end-group \
    -lplibssgaux -lplibssg -lplibsg -lplibsl -lplibsm -lplibjs -lplibul -lm
}
# GL, GLU, GLUT, OpenAL, ALUT, libpng, zlib, vorbis: stubs that return 0
# (some are called by static constructors, e.g. ssggraph's ssgContext).
LINK 2>&1 | sed -n "s/.*undefined reference to \`\([A-Za-z_][A-Za-z0-9_]*\)'.*/\1/p" | sort -u > stubs.txt || true
{ echo '/* made by tests/qemu/build.sh: libraries the console race does not need */'
  while read -r f; do echo "long $f(void) { return 0; }"; done < stubs.txt; } > src/linux/qemu_stubs.c
$X-gcc $QF -fno-builtin -w -c src/linux/qemu_stubs.c -o src/linux/qemu_stubs.o
LINK src/linux/qemu_stubs.o
echo "$(wc -l < stubs.txt) library functions stubbed"
echo "built $T/src/linux/torcs-arm"
