#!/bin/bash
# Host (Linux x86-64) build of the patched TORCS for profiling, with the
# RISC OS start-up and static modules (TORCS_STATIC_MODULES) and the
# software-OpenGL changes (TORCS_SOFTWARE_GL), so it runs the same code
# paths as the Pi apart from the window system.
#   TORCS_SRC=<patched tree from build/fetch.sh> HOSTDIR=<build dir> build-host.sh
# Needs the Ubuntu packages: libplib-dev freeglut3-dev libopenal-dev
# libalut-dev libpng-dev libvorbis-dev libxrandr-dev libxxf86vm-dev.
set -euo pipefail
: "${TORCS_SRC:?}" "${HOSTDIR:?}"
if [ ! -d "$HOSTDIR" ]; then
  mkdir -p "$HOSTDIR"
  (cd "$TORCS_SRC" && git ls-files | tar cf - -T -) | tar xf - -C "$HOSTDIR"
fi
cd "$HOSTDIR"
sed -e 's/^CC = .*/CC = gcc/; s/^CXX = .*/CXX = g++/; s/^LD = .*/LD = ld/; s/^AR = .*/AR = ar/' \
    -e 's/^OBJCOPY = .*/OBJCOPY = objcopy/; s/^RANLIB = .*/RANLIB = ranlib/' \
    -e 's/^CPP = .*/CPP = gcc -E -M -D__DEPEND__/; s/^RISCOS_INC = .*/RISCOS_INC =/' \
    -e 's/^CFLAGSD = .*/CFLAGSD = -D_GNU_SOURCE -DHAVE_CONFIG_H -DTORCS_STATIC_MODULES -DTORCS_SOFTWARE_GL/' \
    Make-config.riscos > Make-config
cp config.h.riscos config.h
export TORCS_BASE=$PWD MAKE_DEFAULT=$PWD/Make-default.mk
export RISCOS_CFLAGS="-O2 -g -fno-delete-null-pointer-checks" RISCOS_MAP= STAGE=/nonexistent RISCOS_DEVKIT=/nonexistent
mkdir -p export/lib export/include
make RISCOS_STATIC=1 > make-host.log 2>&1 || { tail -30 make-host.log; exit 1; }
MODS=$(cd export && find modules drivers -name '*.so' | sort)
TAB=src/linux/riscos_modtab.cpp
{ echo '#include "riscosspec.h"'; echo 'extern "C" {'
  for m in $MODS; do echo "int $(basename "$m" .so)(tModInfo *);"; done
  echo '}'; echo 'const tRiscosModule RiscosModules[] = {'
  for m in $MODS; do n=$(basename "$m" .so); echo "  { \"$(dirname "$m")\", \"$n\", $n, NULL },"; done
  echo '  { NULL, NULL, NULL, NULL } };'; } > $TAB
g++ -O2 -g -Iexport/include -I. -c $TAB -o src/linux/riscos_modtab.o
g++ -o src/linux/torcs-static src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o \
  src/linux/riscos_modtab.o $(for m in $MODS; do echo "export/$m"; done) -Lexport/lib \
  -Wl,--start-group -lracescreens -lraceengine -lclient -lconfscreens -lrobottools -llearning \
  -lmusicplayer -ltgfclient -ltgf -ltxml -lsolid -Wl,--end-group \
  -lplibssgaux -lplibssg -lplibsg -lplibsl -lplibsm -lplibjs -lplibul -lglut -lGLU -lGL \
  -lalut -lopenal -lvorbisfile -lvorbis -logg -lpng -lz -lX11 -lXrandr -lXxf86vm -lm
echo "built $HOSTDIR/src/linux/torcs-static"
