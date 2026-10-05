#!/bin/bash
# Build TORCS for RISC OS in $TORCS_SRC (patched by build/fetch.sh), with
# the libraries from build/build-deps.sh and the riscos-mesa devkit:
#   1. make, with Make-config.riscos: libraries as static archives, each
#      module (graphics, physics, track, robots) as one partly-linked object
#      with only its entry points global (see Make-default.mk);
#   2. the module table (riscos_modtab.cpp) for riscosspec.cpp;
#   3. the final static link: $TORCS_SRC/src/linux/torcs (ELF).
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
arm-riscos-gnueabihf-g++ -static -o src/linux/torcs \
  src/linux/main.o src/linux/riscosspec.o src/linux/riscosplatform.o src/linux/riscos_modtab.o \
  $MODOBJS \
  -Lexport/lib -L"$STAGE/lib" -L"$RISCOS_DEVKIT/lib" \
  -Wl,--start-group $TLIBS -Wl,--end-group \
  -lplibssgaux -lplibssg -lplibsg -lplibsl -lplibsm -lplibjs -lplibul \
  -lglut -lGLU -lalut -lopenal -lSDL2 -lEGL -lOSMesa \
  -lvorbisfile -lvorbis -logg -lpng16 -lz -lstdc++ -lm \
  -Wl,-Map=src/linux/torcs.map
python3 "$RT_DIR/tools/check-stack-probes.py" src/linux/torcs
ls -l src/linux/torcs
