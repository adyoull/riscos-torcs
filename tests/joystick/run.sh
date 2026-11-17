#!/bin/bash
# tests/joystick/run.sh: build plib's RISC OS joystick code for ARM Linux
# with a pretend Joystick module and check what it makes of each answer.
# Needs g++-arm-linux-gnueabihf and riscos-crossdev's qemu-arm-aligntrap
# (RISCOS_TOOLCHAIN), and build/build-deps.sh run first (patched plib).
set -euo pipefail
. "$(dirname "$0")/../../build/env.sh"
P=$WORK/deps/plib-1.8.5/src
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
H=$(cd "$(dirname "$0")" && pwd)
arm-linux-gnueabihf-g++ -static -O1 -w -U__linux__ -U__unix__ -U__linux -Ulinux -Uunix \
  -D__riscos__ -I"$H" -I"$P/js" -I"$P/util" \
  "$H/test_joystick.cxx" "$P/js/jsRISCOS.cxx" "$P/js/js.cxx" -o "$T/t"
Q=$RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap
fail=0
check() { # check NAME EXPECTED VAR=VALUE MODE
  local name=$1 want=$2 var=$3 mode=$4
  local got; got=$(env "$var" "$Q" "$T/t" "$mode" 2>/dev/null | tail -1) || got="crashed"
  if [ "$got" = "$want" ]; then echo "ok: $name"; else echo "FAIL: $name: got '$got', want '$want'"; fail=1; fi
}
STABLE="working=1 name='Joystick (Joystick_Read)' axes=2 buttons=32 b=3 a0=40000 a1=35535"
OFF="working=0 name='' axes=0 buttons=0 b=0 a0=0 a1=0"
check "USBJoystick slot API" "working=1 name='Pad' axes=2 buttons=4 b=5 a0=200 a1=50" X=1 0
check "AxisInfo points at unmapped memory: Joystick_Read" "$STABLE" X=1 1
check "no Joystick module" "$OFF" X=1 2
check "AxisInfo count too big: Joystick_Read" "$STABLE" X=1 3
check 'TORCS$Joystick off' "$OFF" 'TORCS$Joystick=off' 0
check 'TORCS$Joystick stable' "$STABLE" 'TORCS$Joystick=stable' 0
exit $fail
