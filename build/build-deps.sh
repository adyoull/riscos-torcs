#!/bin/bash
# Cross-build the libraries TORCS needs that the riscos-mesa devkit doesn't
# have, into $STAGE (include/ and lib/, static only):
#   libpng 1.6.37, libogg 1.3.5, libvorbis 1.3.7 (menu music),
#   freealut 1.1.0 (TORCS loads its WAVs with alutLoadWAVFile),
#   plib 1.8.5: ul, sg, ssg, ssgAux, js, sl and sm (with patches/plib; sl
#   is silent on RISC OS: TORCS's sound goes through OpenAL).
# The devkit supplies OpenGL (OSMesa), GLU, freeglut, EGL, OpenAL, SDL2, zlib.
#   build/build-deps.sh      (after build/fetch.sh)
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$STAGE/include" "$STAGE/lib" "$WORK/deps"
cd "$WORK/deps"
CF="$RISCOS_CFLAGS $RISCOS_MAP -I$STAGE/include -I$RISCOS_DEVKIT/include"
export PKG_CONFIG_LIBDIR="$STAGE/lib/pkgconfig"

unpack() { # unpack TARBALL DIR
  [ -d "$2" ] || tar xf "$DL/$1"
}

# --- libpng (zlib from the devkit) ---
unpack libpng1.6_1.6.37.orig.tar.gz libpng-1.6.37
if [ ! -f "$STAGE/lib/libpng16.a" ]; then
  (cd libpng-1.6.37 && \
   ./configure --host=$HOST --prefix="$STAGE" --disable-shared --enable-static \
     --enable-arm-neon=no CFLAGS="$CF" CPPFLAGS="-I$RISCOS_DEVKIT/include" \
     LDFLAGS="-L$RISCOS_DEVKIT/lib" >/dev/null && \
   make -j"$JOBS" >/dev/null && make install >/dev/null)
fi

# --- libogg, libvorbis ---
unpack libogg_1.3.5.orig.tar.gz libogg-1.3.5
if [ ! -f "$STAGE/lib/libogg.a" ]; then
  (cd libogg-1.3.5 && \
   ./configure --host=$HOST --prefix="$STAGE" --disable-shared CFLAGS="$CF" >/dev/null && \
   make -j"$JOBS" >/dev/null && make install >/dev/null)
fi
unpack libvorbis_1.3.7.orig.tar.gz libvorbis-1.3.7
if [ ! -f "$STAGE/lib/libvorbisfile.a" ]; then
  (cd libvorbis-1.3.7 && \
   ./configure --host=$HOST --prefix="$STAGE" --disable-shared --disable-oggtest \
     --with-ogg="$STAGE" CFLAGS="$CF" >/dev/null && \
   make -j"$JOBS" -C lib >/dev/null && make -C lib install >/dev/null && \
   make -C include install >/dev/null && \
   mkdir -p "$STAGE/lib/pkgconfig" && cp vorbis.pc vorbisfile.pc "$STAGE/lib/pkgconfig/")
fi

# --- freealut (only its sources: its configure wants to link OpenAL) ---
unpack freealut_1.1.0.orig.tar.gz freealut-1.1.0
if [ ! -f "$STAGE/lib/libalut.a" ]; then
  rm -rf alut-obj; mkdir alut-obj
  for c in freealut-1.1.0/src/*.c; do
    arm-riscos-gnueabihf-gcc $CF -std=gnu99 -DHAVE_STDINT_H=1 -DHAVE___ATTRIBUTE__=1 \
      -DHAVE_NANOSLEEP=1 -DHAVE_TIME_H=1 -DHAVE_STAT=1 -DHAVE_UNISTD_H=1 \
      -DHAVE_SYS_TYPES_H=1 -DHAVE_SYS_STAT_H=1 -DALUT_BUILD_LIBRARY \
      -Ifreealut-1.1.0/include -c "$c" -o "alut-obj/$(basename "$c" .c).o"
  done
  arm-riscos-gnueabihf-ar rcs "$STAGE/lib/libalut.a" alut-obj/*.o
  mkdir -p "$STAGE/include/AL"; cp freealut-1.1.0/include/AL/alut.h "$STAGE/include/AL/"
fi

# --- plib: compiled directly (its configure looks for X11 and GL libs) ---
if [ ! -d plib-1.8.5 ]; then
  tar xf "$DL/plib_1.8.5.orig.tar.gz"
  for p in 04_CVE-2011-4620.diff 05_CVE-2012-4552.diff 08_CVE-2021-38714.patch \
           10-riscos-platform.patch; do
    patch -d plib-1.8.5 -p1 -s < "$RT_DIR/patches/plib/$p"
  done
fi
if [ ! -f "$STAGE/lib/libplibsm.a" ]; then
  P=plib-1.8.5/src
  mkdir -p "$STAGE/include/plib"
  cp $P/util/ul.h $P/util/ulRTTI.h $P/sg/sg.h $P/ssg/ssg.h $P/ssg/ssgconf.h \
     $P/ssg/ssgKeyFlier.h $P/ssgAux/*.h $P/js/js.h $P/sl/sl.h $P/sl/sm.h \
     $P/sl/slPortability.h "$STAGE/include/plib/"
  build_plib() { # build_plib LIB DIR SOURCES...
    local lib=$1 dir=$2; shift 2
    rm -rf "obj-$lib"; mkdir "obj-$lib"
    for s in "$@"; do
      arm-riscos-gnueabihf-g++ $CF -I$P/util -I$P/sg -I$P/ssg -I$P/js -I$P/sl \
        -c "$P/$dir/$s" -o "obj-$lib/${s%.cxx}.o"
    done
    rm -f "$STAGE/lib/libplib$lib.a"
    arm-riscos-gnueabihf-ar rcs "$STAGE/lib/libplib$lib.a" obj-$lib/*.o
  }
  build_plib ul util $(cd $P/util && ls *.cxx)
  build_plib sg sg $(cd $P/sg && ls *.cxx)
  build_plib ssg ssg $(cd $P/ssg && ls *.cxx)
  build_plib ssgaux ssgAux $(cd $P/ssgAux && ls *.cxx)
  build_plib js js js.cxx jsRISCOS.cxx
  build_plib sl sl $(cd $P/sl && ls sl*.cxx)
  build_plib sm sl smMixer.cxx
fi
ls "$STAGE/lib"
