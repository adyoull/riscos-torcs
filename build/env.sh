# Source this: . build/env.sh
# Settings for the riscos-torcs build scripts. Each can be set first.
#   RISCOS_TOOLCHAIN  riscos-crossdev toolchain 1.3 (UnixLib 5.0.3.2, static)
#   RISCOS_DEVKIT     riscos-mesa devkit (12h or later: OpenAL, freeglut, EGL)
#   WORK              where sources, the staged libraries and the build go
#   DL                where the source tarballs are (fetched if missing)
RT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${WORK:=$RT_DIR/work}"
: "${DL:=$WORK/dl}"
: "${JOBS:=$(nproc)}"
: "${RISCOS_TOOLCHAIN:?set RISCOS_TOOLCHAIN to the riscos-crossdev toolchain}"
: "${RISCOS_DEVKIT:?set RISCOS_DEVKIT to the riscos-mesa devkit}"
STAGE=$WORK/stage
TORCS_SRC=$WORK/torcs
export RT_DIR WORK DL JOBS RISCOS_TOOLCHAIN RISCOS_DEVKIT STAGE TORCS_SRC
export PATH="$RISCOS_TOOLCHAIN/bin:$PATH"
HOST=arm-riscos-gnueabihf
# riscos-mesa's flags (docs/porting/README.md). -fstack-clash-protection is
# essential: the ELF stack grows behind a guard page.
# -fno-delete-null-pointer-checks: old engines test this==NULL (YSFlight).
RISCOS_CFLAGS="-O2 -mtune=cortex-a72 -mfpu=vfpv3 -mfloat-abi=hard -fstack-clash-protection -fno-delete-null-pointer-checks"
# No build paths in shipped programs (__FILE__ in asserts).
RISCOS_MAP="-ffile-prefix-map=$WORK=riscos-torcs"
export HOST RISCOS_CFLAGS RISCOS_MAP
