#!/usr/bin/env python3
"""mksprites.py OUT,ff9 IMAGE NAME:SIZE [NAME:SIZE ...]

Write a RISC OS sprite file with one 32 bits-per-pixel sprite per NAME,
each the image scaled to SIZE x SIZE pixels, with a 1 bpp mask from the
image's alpha (alpha < 128 = transparent). New-format sprites (mode word
type 6, 90 x 90 dpi), which RISC OS 3.5 and later show (Filer icons,
icon bar). Used for !TORCS's !Sprites (from TORCS's own Ticon.png).
"""
import struct, sys
from PIL import Image

def sprite(name, im, size):
    im = im.convert('RGBA').resize((size, size), Image.LANCZOS)
    px = im.load()
    image = bytearray()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            image += bytes((r, g, b, 0))          # &00BBGGRR, little-endian
    mask_words = (size + 31) // 32
    mask = bytearray()
    for y in range(size):
        bits = 0
        for x in range(size):
            if px[x, y][3] >= 128:
                bits |= 1 << x
        mask += bits.to_bytes(mask_words * 4, 'little')
    header_size = 44
    img_off = header_size
    mask_off = img_off + len(image)
    total = mask_off + len(mask)
    mode = (6 << 27) | (90 << 14) | (90 << 1) | 1   # 32bpp, 90 dpi
    hdr = struct.pack('<I12sIIIIIII', total, name.encode('latin-1').ljust(12, b'\0'),
                      size - 1, size - 1, 0, 31, img_off, mask_off, mode)
    return hdr + bytes(image) + bytes(mask)

def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    out, src = sys.argv[1], sys.argv[2]
    im = Image.open(src)
    sprites = []
    for spec in sys.argv[3:]:
        name, size = spec.split(':')
        sprites.append(sprite(name.lower(), im, int(size)))
    body = b''.join(sprites)
    # A sprite file is a sprite area without its first word (the size).
    area = struct.pack('<III', len(sprites), 16, 16 + len(body))
    with open(out, 'wb') as fh:
        fh.write(area + body)

if __name__ == '__main__':
    main()
