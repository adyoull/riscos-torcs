#!/usr/bin/env python3
"""frames.py CALLGRIND_OUT NAME: total instructions, frames (calls to
glutSwapBuffers) and instructions per frame."""
import re, sys
path, name = sys.argv[1], sys.argv[2]
names = {}
total = 0
frames = 0
cur_cfn = None
for line in open(path, errors='replace'):
    if line.startswith('summary:') or line.startswith('totals:'):
        total = max(total, int(line.split()[1]))
    m = re.match(r'fn=\((\d+)\) (.*)', line)
    if m:
        names[m.group(1)] = m.group(2).strip()
    m = re.match(r'cfn=\((\d+)\)(?: (.*))?', line)
    if m:
        if m.group(2): names[m.group(1)] = m.group(2).strip()
        cur_cfn = names.get(m.group(1), '')
        continue
    m = re.match(r'calls=(\d+)', line)
    if m and cur_cfn and cur_cfn.split('(')[0] in ('glutSwapBuffers',):
        frames += int(m.group(1))
print("%-14s %8.0fM instr, %5d frames, %6.1fM per frame" % (name, total/1e6, frames, total/1e6/max(frames,1)))
