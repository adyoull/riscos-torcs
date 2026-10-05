#!/bin/bash
# QEMU alignment test: a console race (torcs -r, no graphics) with the
# robots on a track, run by the toolchain's qemu-arm-aligntrap, which stops
# the program on an unaligned access as RISC OS would ("abort on data
# transfer"). Exit status 135 = unaligned access, 132 = VFPv4 instruction.
#   . build/env.sh; TORCS_DATA=<installed data dir> tests/qemu/run.sh [TRACK CAT LAPS ROBOT...]
# (data: work/inst/riscos/share/games/torcs after build/package.sh)
set -uo pipefail
. "$(dirname "$0")/../../build/env.sh"
: "${QDIR:=$WORK/qemu}" "${TORCS_DATA:=$WORK/inst/riscos/share/games/torcs}"
TRACK=${1:-forza}; CAT=${2:-road}; LAPS=${3:-1}; shift 3 2>/dev/null || shift $#
ROBOTS=${*:-berniw berniw2 berniw3 bt damned inferno inferno2 lliaw olethros sparkle tita}
L=$QDIR/local; rm -rf "$L"; mkdir -p "$L/config/raceman" "$L/results"
cp -r "$TORCS_DATA/config/." "$L/config/"
R=$L/config/raceman/qemutest.xml
{
cat <<X
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE params SYSTEM "../params.dtd">
<params name="QEMU test" type="param" mode="mw">
  <section name="Header">
    <attstr name="name" val="QEMU test"/>
    <attstr name="description" val="QEMU alignment test"/>
    <attnum name="priority" val="10"/>
  </section>
  <section name="Tracks">
    <attnum name="maximum number" val="1"/>
    <section name="1"><attstr name="name" val="$TRACK"/><attstr name="category" val="$CAT"/></section>
  </section>
  <section name="Races">
    <section name="1"><attstr name="name" val="Quick Race"/></section>
  </section>
  <section name="Quick Race">
    <attnum name="distance" val="0"/>
    <attstr name="type" val="race"/>
    <attstr name="starting order" val="drivers list"/>
    <attstr name="restart" val="no"/>
    <attstr name="display mode" val="results only"/>
    <attnum name="laps" val="$LAPS"/>
  </section>
  <section name="Drivers">
    <attnum name="maximum number" val="40"/>
X
i=1; for r in $ROBOTS; do
  echo "    <section name=\"$i\"><attnum name=\"idx\" val=\"1\"/><attstr name=\"module\" val=\"$r\"/></section>"
  i=$((i+1))
done
echo "  </section>"
echo "</params>"
} > "$R"
cd "$TORCS_DATA"
QEMU="$RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap" bash "$RT_DIR/tests/qemu/aligntrap.sh" \
  "$QDIR/torcs/src/linux/torcs-arm" -l "$L" -L "$TORCS_DATA" -D "$TORCS_DATA" -r "$R" > "$QDIR/run.log" 2>&1
rc=$?
tail -15 "$QDIR/run.log"
echo "exit status $rc"
ls "$L/results"/* 2>/dev/null | head
exit $rc
