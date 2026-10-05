#!/usr/bin/env python3
"""defaults.py APPDIR: the RISC OS default settings, applied to the game
data in the packaged application (build/package.sh).

The settings files are copied into <Choices$Write>.TORCS on the first run,
so these are only the starting values: everything can be changed in the
game's menus as usual. Everything is drawn by software OpenGL on the Pi's
CPU, so the defaults favour speed (see docs/PORTING-NOTES.md, "Speed",
for the host profile behind each value).
"""
import os, re, sys

app = sys.argv[1]

def edit(rel, fn):
    p = os.path.join(app, rel)
    s = open(p, encoding='utf-8').read()
    t = fn(s)
    if t == s:
        sys.exit('defaults.py: nothing changed in ' + rel)
    open(p, 'w', encoding='utf-8').write(t)

def set_att(s, section, att, val):
    """Set <attnum|attstr name=att val=...> inside <section name=section>."""
    m = re.search(r'<section name="%s">.*?</section>' % re.escape(section), s, re.S)
    if not m:
        sys.exit('defaults.py: no section ' + section)
    body = m.group(0)
    nb, n = re.subn(r'(<att(?:num|str) name="%s"[^>]*? val=")[^"]*"' % re.escape(att),
                    lambda x: x.group(1) + val + '"', body)
    if n == 0:
        sys.exit('defaults.py: no %s in %s' % (att, section))
    return s.replace(body, nb)

# Quick Race: you alone on the track, so the first race shows how fast the
# game runs. Computer drivers can be added in Configure Race.
def quickrace(s):
    return re.sub(r'(<section name="Drivers">.*?<attnum name="focused idx"[^>]*>).*?(\s*</section>\s*<section name="Configuration">)',
                  lambda m: m.group(1) + '\n      <section name="1">\n        <attnum name="idx" val="1"/>\n'
                            '        <attstr name="module" val="human"/>\n      </section>\n' + m.group(2).lstrip('\n'),
                  s, count=1, flags=re.S)
edit('config/raceman/quickrace.xml', quickrace)

# Graphics: fewer smoke particles and skid marks, shorter view distance,
# simple wheels, no sky panorama (a whole screen of textured pixels each
# frame: -22% on the host profile; the sky is then the track's background
# colour). All in Options > Graphic Configuration.
GRAPH = [
    ('Graphic', 'smoke value', '100'),
    ('Graphic', 'skid value', '50'),
    ('Graphic', 'fov factor', '1.0'),
    ('Graphic', 'wheel rendering', 'simple'),
]
def graph(s):
    for sec, att, val in GRAPH:
        s = set_att(s, sec, att, val)
    # Textures at most 512x512 (Options > OpenGL): software OpenGL keeps
    # every texture in RAM and many track textures are 1024x1024; smaller
    # ones also draw faster (fewer cache misses). 
    # The 3D scene drawn at half the screen size (a quarter of the pixels)
    # and stretched, with the race display and menus at the full size
    # (Graphic Configuration, "Scene resolution": stored as a fraction).
    s = s.replace('<attstr name="wheel rendering" val="simple"/>',
                  '<attstr name="wheel rendering" val="simple"/>\n'
                  '    <attstr name="sky background" val="no"/>\n'
                  '    <attnum name="scene scale" val="0.5"/>', 1)
    assert 'scene scale' in s
    assert 'sky background' in s
    assert 'OpenGL Features' not in s
    s = s.replace('</params>', '  <section name="OpenGL Features">\n'
                  '    <attnum name="user texture sizelimit" val="512"/>\n'
                  '  </section>\n</params>')
    return s
edit('config/graph.xml', graph)
