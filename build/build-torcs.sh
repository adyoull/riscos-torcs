#!/bin/bash
# Build TORCS for RISC OS in $TORCS_SRC (patched by build/fetch.sh), with
# the libraries from build/build-deps.sh and the riscos-mesa devkit:
#   1. make, with Make-config.riscos: libraries as static archives, each
#      module (graphics, physics, track, robots) as one partly-linked object
#      with only its entry points global (see Make-default.mk);
#   2. the module table (riscos_modtab.cpp) for riscosspec.cpp;
#   3. the final static link: $TORCS_SRC/src/linux/torcs (ELF), and with
#      MIXED=1 also the mixed program src/linux/torcs-mixed.
# Re-running is safe: make carries on where it stopped.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$TORCS_SRC"
export TORCS_BASE=$PWD MAKE_DEFAULT=$PWD/Make-default.mk
cp Make-config.riscos Make-config
cp config.h.riscos config.h
# The export tree holds symlinks to the built libraries and modules.
mkdir -p export/lib export/include
# Serial: TORCS's recursive make exports headers as it goes.
make RISCOS_STATIC=1 > "$WORK/make.log" 2>&1 || { tail -40 "$WORK/make.log"; exit 1; }

# --- module table ---
cd export
MODS=$(find modules drivers -name '*.so' | sort)
cd ..
TAB=src/linux/riscos_modtab.cpp
{
  echo "/* Made by build/build-torcs.sh: the modules linked into TORCS. */"
  echo "#include \"riscosspec.h\""
  echo "extern \"C\" {"
  for m in $MODS; do
    n=$(basename "$m" .so)
    echo "int $n(tModInfo *);"
    if arm-riscos-gnueabihf-nm "export/$m" | grep -q " T ${n}Shut$"; then
      echo "int ${n}Shut(void);"
    fi
  done
  echo "}"
  echo "const tRiscosModule RiscosModules[] = {"
  for m in $MODS; do
    n=$(basename "$m" .so); d=$(dirname "$m")
    if arm-riscos-gnueabihf-nm "export/$m" | grep -q " T ${n}Shut$"; then s="${n}Shut"; else s=NULL; fi
    echo "  { \"$d\", \"$n\", $n, $s },"
  done
  echo "  { NULL, NULL, NULL, NULL }"
  echo "};"
} > $TAB

# --- link ---
CXXF="$RISCOS_CFLAGS $RISCOS_MAP -D_GNU_SOURCE -Iexport/include -I. -I$STAGE/include -I$RISCOS_DEVKIT/include"
arm-riscos-gnueabihf-g++ $CXXF -c $TAB -o src/linux/riscos_modtab.o
MODOBJS=$(for m in $MODS; do echo "export/$m"; done)
# The libraries, in dependency order (static archives: users first).
TLIBS="-lracescreens -lraceengine -lclient -lconfscreens -lrobottools -llearning \
  -lmusicplayer -ltgfclient -ltgf -ltxml -lsolid"
# RISCOS_UNIXLIB first: the driver's -lunixlib then finds that library
# before the toolchain's.
ULIB=${RISCOS_UNIXLIB:+-L$RISCOS_UNIXLIB}
# GLCOUNT=1 (diagnosis, not for releases): every GL function TORCS and plib
# call is wrapped with a counter (tools/glcount-gen.sh), and the trace
# (TORCS$Trace) writes the counts.
GLC=
if [ -n "${GLCOUNT:-}" ]; then
  "$RT_DIR/tools/glcount-gen.sh" src/linux/glcount \
    src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o $MODOBJS \
    export/lib/*.a "$STAGE"/lib/libplib*.a
  arm-riscos-gnueabihf-gcc -c src/linux/glcount/glcount.s -o src/linux/glcount/glcount_s.o
  arm-riscos-gnueabihf-gcc $RISCOS_CFLAGS -c src/linux/glcount/glcount.c -o src/linux/glcount/glcount_c.o
  GLC="src/linux/glcount/glcount_s.o src/linux/glcount/glcount_c.o $(tr '\n' ' ' < src/linux/glcount/glcount.ld)"
fi
# FDTRACE=1 (diagnosis, not for releases): calls on file descriptors that
# fail with EBADF are logged with their callers (tools/fdtrace.c).
if [ -n "${FDTRACE:-}" ]; then
  arm-riscos-gnueabihf-gcc $RISCOS_CFLAGS -fno-omit-frame-pointer -c "$RT_DIR/tools/fdtrace.c" -o src/linux/fdtrace.o
  for f in read write close fstat fcntl isatty ioctl select dup dup2 lseek poll fsync; do
    GLC="$GLC -Wl,--wrap=$f"
  done
  GLC="$GLC src/linux/fdtrace.o"
fi
arm-riscos-gnueabihf-g++ -static $ULIB -o src/linux/torcs \
  src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o src/linux/riscos_modtab.o \
  $MODOBJS $GLC \
  -Lexport/lib -L"$STAGE/lib" -L"$RISCOS_DEVKIT/lib" \
  -Wl,--start-group $TLIBS -Wl,--end-group \
  -lplibssgaux -lplibssg -lplibsg -lplibsl -lplibsm -lplibjs -lplibul \
  -lglut -lGLU -lalut -lopenal -lSDL2 -lEGL -lOSMesa \
  -lvorbisfile -lvorbis -logg -lpng16 -lz -lstdc++ -lm \
  -Wl,-Map=src/linux/torcs.map
# Which UnixLib was linked (the map names the archive of each member).
grep -o '[^ (]*libunixlib\.a' src/linux/torcs.map | sort -u | sed 's/^/UnixLib: /'
python3 "$RT_DIR/tools/check-stack-probes.py" src/linux/torcs
ls -l src/linux/torcs

# --- MIXED=1: also a mixed program, src/linux/torcs-mixed ---
# The same objects, with UnixLib, libstdc++ and the game's own libraries
# (plib, freealut, libpng, Ogg Vorbis, zlib) linked in, but OpenGL, EGL,
# GLU, freeglut, SDL 2 and OpenAL loaded from !MesaLibs at run time
# (riscos-mesa's docs/porting/mixed.md, riscos-crossdev's docs/MIXED.md).
# lib/shared comes before lib, so those six are found as shared libraries;
# zlib has no shared library (libOSMesa's copy is hidden), so libz.a is
# linked in. SDL's dlopen needs -ldl (the toolchain's stub).
if [ -n "${MIXED:-}" ]; then
  [ -d "$RISCOS_DEVKIT/lib/shared" ] ||
    { echo "MIXED: the devkit has no lib/shared (riscos-mesa 20.3.5-19 or later)" >&2; exit 1; }
  STUBS=$(arm-riscos-gnueabihf-gcc -print-file-name=mixed-stubs)
  # The GPU (riscos-mesa 20.3.5-20 on): -lMesaGPU after -lOSMesa, as
  # riscos-mesa's docs/porting/mixed.md says. RISC3D chooses the graphics
  # backend at run time; TORCS needs nothing else.
  # Linked when the devkit has it; MESAGPU=0 leaves it out.
  GPULIB=
  if [ "${MESAGPU:-1}" != 0 ] && [ -e "$RISCOS_DEVKIT/lib/shared/libMesaGPU.so" ]; then
    GPULIB=-lMesaGPU
  fi
  arm-riscos-gnueabihf-g++ -rdynamic -Wl,-rpath-link="$STUBS" $ULIB -o src/linux/torcs-mixed \
    src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o src/linux/riscos_modtab.o \
    $MODOBJS $GLC \
    -Lexport/lib -L"$STAGE/lib" -L"$RISCOS_DEVKIT/lib/shared" -L"$RISCOS_DEVKIT/lib" \
    -Wl,--start-group $TLIBS -Wl,--end-group \
    -lplibssgaux -lplibssg -lplibsg -lplibsl -lplibsm -lplibjs -lplibul \
    -lglut -lGLU -lalut -lopenal -lSDL2 -lEGL -lOSMesa $GPULIB \
    -lvorbisfile -lvorbis -logg -lpng16 -lz -ldl -lm \
    -Wl,-Map=src/linux/torcs-mixed.map
  grep -o '[^ (]*libunixlib\.a' src/linux/torcs-mixed.map | sort -u | sed 's/^/UnixLib (mixed): /'
  echo "GPU library (mixed): ${GPULIB:-none}"
  python3 "$RT_DIR/tools/check-stack-probes.py" src/linux/torcs-mixed
  ls -l src/linux/torcs-mixed
fi
