# Source this: . build/env.sh
# Settings for the riscos-torcs build scripts. Each can be set first.
#   RISCOS_TOOLCHAIN  riscos-crossdev's toolchain (GCCSDK GCC 10.2, UnixLib
#                     5.0.3.12 from 1.14, static): set in the riscos-crossdev image
#   RISCOS_DEVKIT     the riscos-mesa devkit (OpenAL, freeglut, EGL). Used
#                     only if it's the version .riscos-deps names; otherwise
#                     the one build/fetch.sh downloads into $WORK is used
#                     (the riscos-crossdev image's devkit can be older)
#   RISCOS_UNIXLIB    optional: a directory with a libunixlib.a linked
#                     instead of the toolchain's
#   WORK              where sources, the staged libraries and the build go
#   DL                where the source tarballs are (fetched if missing)
RT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${WORK:=$RT_DIR/work}"
: "${DL:=$WORK/dl}"
: "${JOBS:=$(nproc)}"
: "${RISCOS_TOOLCHAIN:?set RISCOS_TOOLCHAIN to the riscos-crossdev toolchain}"
: "${RISCOS_DEVKIT:=}"
# The riscos-mesa devkit .riscos-deps names.
MESA_VERSION=$(awk '$1 == "riscos-mesa" || $1 == "adyoull/riscos-mesa" {sub(/^v/, "", $2); print $2}' "$RT_DIR/.riscos-deps")
[ -n "$MESA_VERSION" ] || { echo ".riscos-deps has no riscos-mesa line" >&2; exit 1; }
MESA_DEVKIT_FILE=riscos-mesa-devkit-$MESA_VERSION.tgz
MESA_DEVKIT_URL=https://github.com/adyoull/riscos-mesa/releases/download/v$MESA_VERSION/$MESA_DEVKIT_FILE
if [ "$(cat "$RISCOS_DEVKIT/VERSION" 2>/dev/null)" != "riscos-mesa devkit $MESA_VERSION" ]; then
  RISCOS_DEVKIT=$WORK/riscos-mesa-devkit-$MESA_VERSION
fi
STAGE=$WORK/stage
TORCS_SRC=$WORK/torcs
if [ -n "${RISCOS_UNIXLIB:-}" ] && [ ! -f "$RISCOS_UNIXLIB/libunixlib.a" ]; then
  echo "RISCOS_UNIXLIB: no libunixlib.a in $RISCOS_UNIXLIB" >&2; exit 1
fi
export RT_DIR WORK DL JOBS RISCOS_TOOLCHAIN RISCOS_DEVKIT RISCOS_UNIXLIB STAGE TORCS_SRC MESA_VERSION MESA_DEVKIT_FILE MESA_DEVKIT_URL
export PATH="$RISCOS_TOOLCHAIN/bin:$PATH"
HOST=arm-riscos-gnueabihf
# riscos-mesa's flags (docs/porting/README.md). -fstack-clash-protection is
# essential: the ELF stack grows behind a guard page.
# -fno-delete-null-pointer-checks: old engines test this==NULL (YSFlight).
RISCOS_CFLAGS="-O2 -mtune=cortex-a72 -mfpu=vfpv3 -mfloat-abi=hard -fstack-clash-protection -fno-delete-null-pointer-checks"
# No build paths in shipped programs (__FILE__ in asserts).
RISCOS_MAP="-ffile-prefix-map=$WORK=riscos-torcs"
export HOST RISCOS_CFLAGS RISCOS_MAP
