#!/bin/bash
# Host profile of a TORCS race frame on riscos-mesa's software renderer
# (see README.md). Instruction counts per frame from callgrind.
#   run.sh NAME [SECTION:ATTR=VALUE ...]
# e.g. run.sh base;  run.sh nosmoke "Graphic:smoke value=0"
# Needs: TORCS_BIN (host build with -DTORCS_STATIC_MODULES, or plain),
# TORCS_DATA (installed data dir), GLDIR (riscos-mesa xlib libGL.so.1),
# Xvfb, xdotool, valgrind. Settings: PROF_TRACK (forza), PROF_ROBOTS
# (berniw olethros lliaw tita), PROF_MULTITEX=1 (pass -M: multitexturing),
# PROF_WAIT (seconds from "New Race" to measuring, 300), PROF_SECS (120).
set -euo pipefail
NAME=${1:?usage: run.sh NAME [SECTION:ATTR=VALUE ...]}; shift
: "${TORCS_BIN:?}" "${TORCS_DATA:?}" "${GLDIR:?}"
: "${PROF_TRACK:=forza}" "${PROF_CAT:=road}" "${PROF_ROBOTS=berniw olethros lliaw tita}"
: "${PROF_WAIT:=300}" "${PROF_SECS:=120}" "${OUT:=/tmp/torcsprof}"
mkdir -p "$OUT"; L="$OUT/local-$NAME"; rm -rf "$L"; mkdir -p "$L/config/raceman" "$L/drivers/human" "$L/results"
D="$TORCS_DATA"
cp "$D"/config/*.xml "$D"/config/*.xsl "$L/config/"; cp "$D"/config/raceman/*.xml "$L/config/raceman/"
cp "$D"/drivers/human/*.xml "$L/drivers/human/"
# Quick race: the track, the robots and the human player (idx 1, not driving).
python3 - "$L/config/raceman/quickrace.xml" "$PROF_TRACK" "$PROF_CAT" "$PROF_ROBOTS" <<'PY'
import re, sys
p, track, cat, robots = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split()
s = open(p).read()
s = re.sub(r'(<section name="Tracks">.*?<attstr name="name" val=")[^"]*(".*?<attstr name="category" val=")[^"]*"',
           lambda m: m.group(1) + track + m.group(2) + cat + '"', s, count=1, flags=re.S)
drv = ['      <section name="%d">\n        <attnum name="idx" val="%d"/>\n        <attstr name="module" val="%s"/>\n      </section>' % (i+1, idx, mod)
       for i, (idx, mod) in enumerate([(1, 'human')] + [(1, r) for r in robots])]
s = re.sub(r'(<section name="Drivers">.*?<attnum name="focused idx"[^>]*>).*?(\n    </section>\n    <section name="Configuration">)',
           lambda m: m.group(1) + '\n' + '\n'.join(drv) + m.group(2), s, count=1, flags=re.S)
open(p, 'w').write(s)
PY
# Overrides in graph.xml: "Section:attr=value"
for o in "$@"; do
  sec=${o%%:*}; rest=${o#*:}; att=${rest%%=*}; val=${rest#*=}
  python3 - "$L/config/graph.xml" "$sec" "$att" "$val" <<'PY'
import re, sys
p, sec, att, val = sys.argv[1:]
s = open(p).read()
m = re.search(r'<section name="%s">.*?</section>' % re.escape(sec), s, re.S)
body = m.group(0)
nb, n = re.subn(r'(<att(?:num|str) name="%s" val=")[^"]*"' % re.escape(att), lambda x: x.group(1) + val + '"', body)
if n == 0: sys.exit("no %s in %s" % (att, sec))
open(p, 'w').write(s.replace(body, nb))
PY
done
# PROF_TEXSIZE: the "user texture sizelimit" (Options > OpenGL)
if [ -n "${PROF_TEXSIZE:-}" ]; then
  sed -i "s|</params>|  <section name=\"OpenGL Features\">\n    <attnum name=\"user texture sizelimit\" val=\"$PROF_TEXSIZE\"/>\n  </section>\n</params>|" "$L/config/graph.xml"
fi
DISP=:${PROF_DISPLAY:-7}
pgrep -f "Xvfb $DISP" >/dev/null || (Xvfb $DISP -screen 0 1024x768x24 >/dev/null 2>&1 &); sleep 2
export DISPLAY=$DISP LD_LIBRARY_PATH="$GLDIR"
ARGS="-l $L -L $D -D $D"; [ -n "${PROF_MULTITEX:-}" ] && ARGS="$ARGS -M"
CG="$OUT/$NAME.cg"; rm -f "$CG"
(cd "$D" && valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file="$CG" \
   "$TORCS_BIN" $ARGS > "$OUT/$NAME.log" 2>&1 &)
click() { xdotool mousemove 320 90 click 1; }
sleep 40; click; sleep 15; click; sleep 15; click
sleep "$PROF_WAIT"
import -window root "$OUT/$NAME-start.png"
callgrind_control -i on >/dev/null
sleep "$PROF_SECS"
callgrind_control -i off >/dev/null
import -window root "$OUT/$NAME.png"
callgrind_control -d >/dev/null; sleep 5
pkill -f "callgrind.*$(basename "$TORCS_BIN")" || true; sleep 3
F=$(ls -S "$CG"* | head -1)
python3 "$(dirname "$0")/frames.py" "$F" "$NAME"
