#!/bin/bash
# Check the mixed program (after MIXED=1 build/build-torcs.sh) with
# riscos-crossdev's checks ($RCD_DIR, as in its image): check-all, and
# check-mixed-package against the !MesaLibs of the devkit it was linked
# with, so every library it needs is there and defines what it needs.
set -euo pipefail
. "$(dirname "$0")/env.sh"
: "${RCD_DIR:?set RCD_DIR to riscos-crossdev (its checks/)}"
P="$TORCS_SRC/src/linux/torcs-mixed"
"$RCD_DIR/checks/check-all.sh" "$P"
"$RCD_DIR/checks/check-mixed-package.sh" "$P" "$RISCOS_DEVKIT/riscos/!MesaLibs/lib"
